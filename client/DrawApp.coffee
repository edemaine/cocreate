import React, {useEffect, useLayoutEffect, useRef} from 'react'
import {useParams} from 'react-router-dom'
import {useTracker} from 'meteor/react-meteor-data'

import {mainBoard, historyBoard, historyMode, setMainBoard, setHistoryBoard, currentBoard, currentPage, currentPageId, currentRoom, currentTool, currentColor, currentFill, currentFillOn, currentFontSize} from './AppState'
import {Board} from './Board'
import {Name, name} from './Name'
import {Page} from './Page'
import {PageList} from './PageList'
import {Room} from './Room'
import {ToolCategory} from './Tool'
import {undoStack} from './UndoStack'
import {lastTool, selectTool, clickTool, stopTool, resumeTool, tools, toolsByHotkey, restrictTouch} from './tools/tools'
import {tryAddImage} from './tools/image'
import {pointers, setSelection} from './tools/modes'
import {snapPoint} from './tools/settings'
import {useHorizontalScroll} from './lib/hscroll'
import {LoadingIcon} from './lib/icons'
import dom from './lib/dom'
import remotes from './lib/remotes'

onResize = ->
  mainBoard.resize()
  historyBoard.resize()
  currentPage.get()?.resize()
  undefined

export DrawApp = React.memo ->
  ## Board data structures
  mainBoardRef = useRef()
  historyBoardRef = useRef()
  useEffect ->
    setMainBoard new Board mainBoardRef.current
    setHistoryBoard new Board historyBoardRef.current, true  # read-only
    onResize()
    window.addEventListener 'resize', onResize
    #observer = new ResizeObserver onResize
    #observer.observe mainBoardRef.current
    #observer.observe historyBoardRef.current
    #observer.observe document.getElementById('center')
    ->
      window.removeEventListener 'resize', onResize
      #observer.disconnect()
      historyBoard.destroy()
      mainBoard.destroy()
  , []

  ## Room data structure
  {roomId} = useParams()
  useLayoutEffect ->
    currentRoom.set new Room roomId
    currentPageId.set null  # reset currentPage
    ->
      currentRoom.get().stop()
      currentRoom.set null
  , [roomId]

  ## Test whether room is loading and/or bad
  room = useTracker ->
    currentRoom.get()
  , []
  {loading, bad} = useTracker ->
    return {} unless room?
    loading: room.loading()
    bad: room.bad()
  , [room]

  ## Page data structure, and stop/resume current tool
  pageId = useTracker ->
    id = currentPageId.get()
    ## Auto load first page
    if not id and (pages = room?.data()?.pages)?.length
      currentPageId.set pages[0]
    id
  , [room]
  remotesRef = useRef()
  useEffect -> # wait for mainBoard to be set
    return unless pageId?
    currentPage.set new Page pageId, room, mainBoard, remotesRef.current
    resumeTool()
    ->
      stopTool()  # stop current tool
      currentPage.get()?.stop()
      currentPage.set null
  , [room, pageId, mainBoard]

  ## Horizontal scroll wheel behavior
  topRef = useRef()
  attribsRef = useRef()
  useHorizontalScroll topRef
  useHorizontalScroll attribsRef

  ## Work around https://bugzilla.mozilla.org/show_bug.cgi?id=764076
  toolsRef = useRef()
  useEffect ->
    window.addEventListener 'resize', onToolsResize = ->
      paletteSize = getComputedStyle document.documentElement
      .getPropertyValue '--palette-size'
      .replace /px$/, ''
      paletteSize = parseInt paletteSize
      if toolsRef.current.scrollHeight > toolsRef.current.clientHeight
        if toolsRef.current.offsetWidth == paletteSize
          toolsRef.current.style.width = "#{paletteSize + toolsRef.current.offsetWidth - toolsRef.current.clientWidth}px"
      else
        toolsRef.current.style.width = null
    onToolsResize()
    -> window.removeEventListener 'resize', onToolsResize
  , []

  ## Update our remote cursor
  updateRemote = (e) ->
    remote =
      name: name.get().trim()
      room: currentRoom.get().id
      page: currentPage.get().id
      tool: currentTool.get()
      color: currentColor.get()
    remote.cursor = currentBoard().eventToPointW e if e?
    remote.fill = currentFill.get() if currentFillOn.get()
    remotes.update remote
  useEffect ->
    dom.listen mainBoardRef.current, pointermove: (e) ->
      return unless currentRoom.get()? and currentPage.get()?
      return unless currentBoard() == mainBoard
      return if restrictTouch e
      updateRemote e
  , []
  ## Cursorless update when page changes
  useEffect ->
    return unless room? and pageId?
    updateRemote()
    undefined
  , [room, pageId]

  ## Pointer event handlers used on both boards
  useEffect ->
    middleDown = false
    oldPointers = null
    dom.listen [mainBoardRef.current, historyBoardRef.current],
      pointerdown: (e) ->
        e.preventDefault()
        return if restrictTouch e
        text.blur() for text in document.querySelectorAll 'input'
        window.focus()  # for getting keyboard focus when <iframe>d
        if e.button == 1 and currentTool.get() != 'pan'
          middleDown = true
          oldPointers = {}
          oldPointers[key] = pointers[key] for own key of pointers
          selectTool 'pan', noStop: true
        tools[currentTool.get()].down? e
      pointerenter: (e) ->
        e.preventDefault()
        return if restrictTouch e
        tools[currentTool.get()].down? e if e.buttons
      pointerup: stop = (e) ->
        e.preventDefault()
        return if restrictTouch e
        tools[currentTool.get()].up? e
        if e.button == 1 and middleDown
          selectTool lastTool, noStart: true
          pointers[key] = oldPointers[key] for own key of oldPointers
          middleDown = false
      pointerleave: stop
      pointermove: (e) ->
        e.preventDefault()
        return if restrictTouch e
        tools[currentTool.get()].move? e
      contextmenu: (e) ->
        ## Prevent right click from bringing up context menu, as it interferes
        ## with e.g. drawing.
        e.preventDefault()
      wheel: (e) ->
        e.preventDefault()
        transform = currentBoard().transform
        {deltaX, deltaY} = e
        ## Convert Shift + 1D wheel into horizontal scroll.  MacOS seems to do
        ## this automatically (hence the deltaX check) but Windows doesn't.
        if not e.ctrlKey and e.shiftKey and e.deltaX == 0
          [deltaX, deltaY] = [deltaY, deltaX]
        switch e.deltaMode
          #when WheelEvent.DOM_DELTA_PIXEL
          when WheelEvent.DOM_DELTA_LINE
            deltaX *= 50
            deltaY *= 50
          when WheelEvent.DOM_DELTA_PAGE
            deltaX *= currentBoard().bbox.width
            deltaY *= currentBoard().bbox.height
        if e.ctrlKey
          ## Ensure zoom-out motion is inverse of equivalent zoom-in
          factor = 1 + 0.01 * Math.abs deltaY
          factor = 1/factor if deltaY > 0
          currentBoard().setScaleFixingPoint transform.scale * factor,
            x: e.offsetX
            y: e.offsetY
        else
          currentBoard().setTransform
            x: transform.x - deltaX / transform.scale
            y: transform.y - deltaY / transform.scale
  , []

  ## Drag and drop
  useEffect ->
    dragDepth = 0
    all = (e) ->
      e.preventDefault()
      e.dataTransfer.dropEffect = 'copy'
    dom.listen mainBoardRef.current,
      dragenter: (e) ->
        all e
        return if dragDepth++
        ## Entering for the first time
        document.getElementById('dragzone').classList.add 'drag'
      dragover: (e) ->
        all e
        #return unless dragDepth
      dragleave: (e) ->
        all e
        return if --dragDepth
        ## Leaving for the last time
        document.getElementById('dragzone').classList.remove 'drag'
      drop: (e) ->
        all e
        dragDepth = 0
        document.getElementById('dragzone').classList.remove 'drag'
        tryAddImage e.dataTransfer.items,
          pts: [snapPoint currentBoard().eventToPoint e]
  , []

  ## Keyboard and copy/paste
  useEffect ->
    spaceDown = false
    oldPointers = null
    dom.listen window,
      keydown: (e) ->
        return if e.target.classList.contains 'modal'
        switch e.key
          when 'z', 'Z'
            if e.ctrlKey or e.metaKey
              if e.shiftKey
                tools.redo.click()
              else
                tools.undo.click()
          when 'y', 'Y'
            if e.ctrlKey or e.metaKey
              tools.redo.click()
          when 'Delete', 'Backspace'
            currentBoard()?.selection?.delete()
          when ' '  ## pan via space-drag
            if currentTool.get() != 'pan'
              spaceDown = true
              oldPointers = {}
              oldPointers[key] = pointers[key] for own key of pointers
              selectTool 'pan', noStop: true
          when 'd', 'D'  ## duplicate
            if (e.ctrlKey or e.metaKey) and
               currentBoard()?.selection?.nonempty()
              e.preventDefault()  # ctrl-D bookmarks on Chrome
              currentBoard().selection.duplicate()
          when 'Escape'
            if historyMode.get()
              historyMode.set false  # escape history view by toggling
          else
            ## Prevent e.g. ctrl-1 browser shortcut (go to tab 1) from also
            ## triggering width 1 hotkey.
            return if e.ctrlKey or e.metaKey or e.altKey
            if e.key of toolsByHotkey
              clickTool toolsByHotkey[e.key]
            else
              clickTool toolsByHotkey[e.key.toLowerCase()]
      keyup: (e) ->
        switch e.key
          when ' '  ## end of pan via space-drag
            if spaceDown
              selectTool lastTool, noStart: true
              pointers[key] = oldPointers[key] for own key of oldPointers
              spaceDown = false
      copy: onCopy = (e) ->
        ## Ignore paste operations within text boxes
        return if e.target.tagName in ['INPUT', 'TEXTAREA']
        return unless currentBoard()?.selection?.nonempty()
        e.preventDefault()
        e.clipboardData.setData 'application/cocreate-objects',
          currentBoard().selection.json()
        e.clipboardData.setData 'image/svg+xml',
          tools.downloadSVG.click null, false
        true
      cut: (e) ->
        if onCopy e
          currentBoard()?.selection?.delete()
      paste: (e) ->
        return if currentBoard().readonly
        ## Ignore paste operations within text boxes
        return if e.target.tagName in ['INPUT', 'TEXTAREA']
        e.preventDefault()
        if (json = e.clipboardData.getData 'application/cocreate-objects')
          objects =
            for obj in JSON.parse json
              delete obj._id
              delete obj.id  # object ID when pasting from history
              delete obj.created
              delete obj.updated
              obj.room = currentRoom.get().id
              obj.page = currentPage.get().id
              obj._id = Meteor.apply 'objectNew', [obj], returnStubValue: true
              obj
          undoStack.push
            type: 'multi'
            ops:
              for obj in objects
                type: 'new'
                obj: obj
          selectTool 'select'  # usually want to move pasted objects
          setSelection (obj._id for obj in objects)
        else
          ## Cache text content in case we want to paste it later; walking
          ## through all items during `tryAddImage` seems to clear text content.
          text = e.clipboardData.getData 'text/plain'
          obj =
            pts: [snapPoint currentBoard().relativePoint 0.25, 0.25]
          ## First check for image paste
          if (image = await tryAddImage e.clipboardData.items, obj)?
            setSelection [image._id]
          ## On failure, paste text content as text object
          else if text
            selectTool 'text'
            undoStack.pushAndDo
              type: 'new'
              obj: obj =
                room: currentRoom.get().id
                page: currentPage.get().id
                type: 'text'
                text: text
                pts: obj.pts
                color: currentColor.get()
                fontSize: currentFontSize.get()
            setSelection [obj._id]
  , []

  ## Initialize tools (after boards are created)
  useEffect ->
    toolSpec.init?() for tool, toolSpec of tools
  , []

  ## Tool-specific effect hook
  tool = useTracker ->
    currentTool.get()
  , []
  useEffect ->
    tools[tool].startEffect?()
  , [tool]
  useEffect onResize, [tool]  # text and image tools affect layout

  history = useTracker ->
    historyMode.get()
  , []
  useLayoutEffect ->
    ## Maintain history class on <body>, which adds sepia tone
    dom.classSet document.body, 'history', history
    ## Preserve transform between two boards when switching history mode
    ->
      if history
        mainBoard.setTransform historyBoard.transform
      else
        historyBoard.setTransform mainBoard.transform
  , [history]

  return <BadRoom/> if bad and not loading

  <div id="container">
    <div id="tools" className="vertical palette" ref={toolsRef}>
      <ToolCategory category="undo" placement="right"/>
      <ToolCategory category="mode" placement="right"/>
      <div className="spacer"/>
      <ToolCategory category="setting" placement="right"/>
      <ToolCategory category="room" placement="right"/>
      <ToolCategory category="download" placement="right"/>
      <ToolCategory category="settings" placement="right"/>
      <ToolCategory category="link" placement="right"/>
    </div>
    <div id="pages" className="top horizontal palette" ref={topRef}>
      <ToolCategory category="zoom" placement="bottom"/>
      <div className="spacer"/>
      <PageList/>
      <ToolCategory category="page" placement="bottom"/>
      <div className="spacer"/>
      <Name/>
    </div>
    <div id="bottom" className="horizontal super palette">
      {if tool == 'text'
        <div id="text" className="horizontal palette">
          <textarea id="textInput" type="text" placeholder='(type text here)'/>
        </div>
      }
      {if history
        <div id="history" className="horizontal palette">
          <tools.history.Slider/>
        </div>
      else if tool == 'image'
        <div id="imageUrl" className="horizontal palette">
          <input id="urlInput" type="text" placeholder='(enter image URL here)'/>
        </div>
      else
        <div id="attribs" className="horizontal palette" ref={attribsRef}>
          {if tool == 'text'
            <div id="fontSizes" className="subpalette">
              <ToolCategory category="fontSize" placement="top"/>
            </div>
          else
            <div id="widths" className="subpalette">
              <ToolCategory category="width" placement="top"/>
            </div>
          }
          <div id="colors" className="subpalette">
            <ToolCategory category="color" placement="top"/>
          </div>
        </div>
      }
    </div>
    <div id="center" className={"nopage" unless pageId?}>
      {###touch-action="none" attribute triggers Pointer Events Polyfill (pepjs)
       ###}
      <svg id="mainBoard" className="board" touch-action="none"
       ref={mainBoardRef} style={display: 'none' if history}>
        <filter id="selectFilter">
          <feGaussianBlur stdDeviation="5"/>
        </filter>
      </svg>
      <svg id="historyBoard" className="board historyShow" touch-action="none"
       ref={historyBoardRef} style={display: 'none' unless history}/>
      <svg id="remotes" className="board overlay"
       ref={remotesRef} style={display: 'none' if history}/>
      <div id="dragzone" className="overlay"/>
    </div>
    {if loading
      <LoadingIcon/>
    }
  </div>

DrawApp.displayName = 'DrawApp'

export BadRoom = React.memo ->
  <div className="modal error">
    <h1>Invalid Room ID</h1>
    <p>Perhaps there's a typo in the URL?  It should look like this:</p>
    <pre>{Meteor.absoluteUrl 'r/gLoBaLlYuNiQuEiD7'}</pre>
    <p>Please double-check your copy/paste.</p>
    <p>Or <a href={Meteor.absoluteUrl()}>create a new room</a>.</p>
  </div>
BadRoom.displayName = 'BadRoom'
