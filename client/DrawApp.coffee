import {createEffect, createRenderEffect, on as on_, onCleanup, onMount, Match, Show, Switch} from 'solid-js'
import {useLocation, useParams, useNavigate} from 'solid-app-router'
import {createTracker} from 'solid-meteor-data'

import {setRouterNavigate, mainBoard, historyBoard, historyMode, setMainBoard, setHistoryBoard, currentBoard, currentPage, currentPageId, currentRoom, currentTool, currentColor, currentFill, currentFillOn, currentFontSize, currentOpacity, currentOpacityOn} from './AppState'
import {Board} from './Board'
import {maybeSnapPointToGrid} from './Grid'
import {Name, name} from './Name'
import {Page} from './Page'
import {PageList} from './PageList'
import {Room} from './Room'
import {ToolCategory} from './Tool'
import {undoStack} from './UndoStack'
import {selectTool, clickTool, stopTool, resumeTool, pushTool, popTool, tools, toolsByHotkey, restrictTouchDraw} from './tools/tools'
import {tryAddImage} from './tools/image'
import {setSelection} from './tools/modes'
import {createHorizontalScroll} from './lib/hscroll'
import {LoadingIcon} from './lib/icons'
import dom from './lib/dom'
import remotes from './lib/remotes'
import storage from './lib/storage'

onResize = ->
  mainBoard.resize()
  historyBoard.resize()
  currentPage.get()?.resize()

export DrawApp = ->
  ## Room data structure
  params = useParams()
  createRenderEffect ->
    currentRoom.set new Room params.roomId
    currentPageId.set null  # reset currentPage
    onCleanup ->
      currentRoom.get().stop()
      currentRoom.set null

  ## Test whether room is bad (and not still loading)
  bad = createTracker -> currentRoom.get()?.bad()

  <Show when={not bad()} fallback={<BadRoom/>}>
    <DrawAppRoom/>
  </Show>

export DrawAppRoom = ->
  ## Board data structures
  mainBoardRef = historyBoardRef = null
  onMount ->
    setMainBoard new Board mainBoardRef
    setHistoryBoard new Board historyBoardRef, true  # read-only
    onResize()
    window.addEventListener 'resize', onResize
    #observer = new ResizeObserver onResize
    #observer.observe mainBoardRef
    #observer.observe historyBoardRef
    #observer.observe document.getElementById('center')
    onCleanup ->
      window.removeEventListener 'resize', onResize
      #observer.disconnect()
      historyBoard.destroy()
      mainBoard.destroy()

  ## Test whether room is loading
  room = createTracker -> currentRoom.get()
  loading = createTracker -> room()?.loading()

  ## Page data structure, and stop/resume current tool
  params = useParams()
  location = useLocation()
  navigate = useNavigate()
  setRouterNavigate navigate
  pageId = createTracker ->
    id = currentPageId.get()
    hashId = location.hash
    pages = room()?.data()?.pages
    pageStorage = new storage.StringVariable "#{params.roomId}.page", undefined, false
    ## Check for initial or changed hash indicating page ID
    if hashId
      if id != hashId and pages?
        if hashId in pages
          currentPageId.set hashId
          pageStorage.set hashId
        else if not loading() ## Invalid page hash: redirect to remove from URL
          Meteor.defer -> navigate location.pathname, replace: true
    else if not id and pages?.length
      ## Use last page recorded in localStorage if there is one.
      if (storageId = pageStorage.get()) and storageId in pages
        currentPageId.set storageId
      else
        ## Auto load first page by default
        currentPageId.set pages[0]
    id
  remotesRef = null
  createEffect -> # wait for mainBoard to be set
    return unless pageId()?
    currentPage.set new Page pageId(), room(), mainBoard, remotesRef
    resumeTool()
    onCleanup ->
      stopTool()  # stop current tool
      currentPage.get()?.stop()
      currentPage.set null

  ## Horizontal scroll wheel behavior
  topRef = attribsRef = null
  createHorizontalScroll -> topRef
  createHorizontalScroll -> attribsRef

  ## Work around https://bugzilla.mozilla.org/show_bug.cgi?id=764076
  toolsRef = null
  onMount ->
    window.addEventListener 'resize', onToolsResize = ->
      paletteSize = getComputedStyle document.documentElement
      .getPropertyValue '--palette-size'
      .replace /px$/, ''
      paletteSize = parseInt paletteSize
      if toolsRef.scrollHeight > toolsRef.clientHeight
        if toolsRef.offsetWidth == paletteSize
          toolsRef.style.width = "#{paletteSize + toolsRef.offsetWidth - toolsRef.clientWidth}px"
      else
        toolsRef.style.width = null
    onCleanup -> window.removeEventListener 'resize', onToolsResize
    onToolsResize()

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
    remote.opacity = currentOpacity.get() if currentOpacityOn.get()
    remotes.update remote
  onMount ->
    onCleanup dom.listen mainBoardRef, pointermove: (e) ->
      return unless currentRoom.get()? and currentPage.get()?
      return unless currentBoard() == mainBoard
      return if restrictTouchDraw e
      updateRemote e
  ## Cursorless update when page changes
  createEffect ->
    return unless room()? and pageId()?
    updateRemote()

  onMount ->
    ## Pointer event handlers used on both boards
    middleDown = null
    spaceDown = null
    onCleanup dom.listen [mainBoardRef, historyBoardRef],
      pointerdown: (e) ->
        e.preventDefault()
        return tools.multitouch.down? e if restrictTouchDraw e
        text.blur() for text in document.querySelectorAll 'input'
        window.focus()  # for getting keyboard focus when <iframe>d
        ## Pan via middle-button drag
        if e.button == 1 and currentTool.get() != 'pan' and
           not middleDown and not spaceDown
          middleDown = pushTool 'pan'
        tools[currentTool.get()].down? e
      pointerenter: (e) ->
        e.preventDefault()
        return tools.multitouch.enter? e if restrictTouchDraw e
        ## Stop middle-button pan if we re-enter board with button released
        if middleDown and (e.buttons & 4) == 0
          middleDown = popTool middleDown
        tools[currentTool.get()].down? e if e.buttons
      pointerup: stop = (e) ->
        e.preventDefault()
        return tools.multitouch.up? e if restrictTouchDraw e
        tools[currentTool.get()].up? e
        if e.button == 1 and middleDown  ## end middle-button pan
          middleDown = popTool middleDown
      pointerleave: stop
      pointermove: (e) ->
        e.preventDefault()
        return tools.multitouch.move? e if restrictTouchDraw e
        tools[currentTool.get()].move? e
      touchmove: (e) ->
        ## This workaround fixes pointer events on iOS with Scribble enabled.
        ## See https://mikepk.com/2020/10/iOS-safari-scribble-bug/
        e.preventDefault()
      contextmenu: (e) ->
        ## Prevent right click from bringing up context menu, as it interferes
        ## with e.g. drawing.
        e.preventDefault()
      auxclick: (e) ->
        ## Prevent middle click from pasting in X-windows.
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
            deltaX *= currentBoard().clientBBox.width
            deltaY *= currentBoard().clientBBox.height
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
    ## Keyboard and copy/paste
    onCleanup dom.listen window,
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
            if currentTool.get() != 'pan' and not middleDown and not spaceDown 
              spaceDown = pushTool 'pan'
          when 'd', 'D'  ## duplicate
            if (e.ctrlKey or e.metaKey) and currentTool.get() == 'select'
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
              spaceDown = popTool spaceDown
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
            pts: [maybeSnapPointToGrid currentBoard().relativePoint 0.25, 0.25]
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

  ## Drag and drop
  onMount ->
    dragDepth = 0
    all = (e) ->
      e.preventDefault()
      e.dataTransfer.dropEffect = 'link'
    onCleanup dom.listen mainBoardRef,
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
        e.stopPropagation()
        dragDepth = 0
        document.getElementById('dragzone').classList.remove 'drag'
        tryAddImage e.dataTransfer.items,
          pts: [maybeSnapPointToGrid currentBoard().eventToPoint e]

  ## Initialize tools (after boards are created)
  onMount ->
    toolSpec.init?() for toolName, toolSpec of tools

  ## Tool-specific effect hook
  tool = createTracker -> currentTool.get()
  createEffect ->
    tools[tool()].startEffect?()
  createEffect on_ tool, onResize  # text and image tools affect layout

  opacityOn = createTracker -> currentOpacityOn.get()

  history = createTracker -> historyMode.get()
  createEffect ->
    ## Maintain history class on <body>, which adds sepia tone
    dom.classSet document.body, 'history', history()
    ## Preserve transform between two boards when switching history mode
    onCleanup ->
      if history()
        historyBoard.setTransform mainBoard.transform
      else
        mainBoard.setTransform historyBoard.transform

  <div id="container">
    <div id="tools" class="vertical palette" ref={toolsRef}>
      <ToolCategory category="undo" placement="right"/>
      <ToolCategory category="mode" placement="right"/>
      <div class="spacer"/>
      <ToolCategory category="setting" placement="right"/>
      <ToolCategory category="room" placement="right"/>
      <ToolCategory category="download" placement="right"/>
      <ToolCategory category="settings" placement="right"/>
      <ToolCategory category="link" placement="right"/>
    </div>
    <div id="pages" class="top horizontal palette" ref={topRef}>
      <ToolCategory category="zoom" placement="bottom"/>
      <div class="spacer"/>
      <PageList/>
      <ToolCategory category="page" placement="bottom"/>
      <div class="spacer"/>
      <Name/>
    </div>
    <div id="bottom" class="horizontal super palette">
      <Show when={tool() == 'text'}>
        <div id="text" class="horizontal palette">
          <textarea id="textInput" type="text" placeholder='(type text here)'/>
        </div>
      </Show>
      <Switch>
        <Match when={history()}>
          <div id="history" class="horizontal palette">
            <tools.history.Slider/>
          </div>
        </Match>
        <Match when={tool() == 'image'}>
          <div id="imageUrl" class="horizontal palette">
            <input id="urlInput" type="text" placeholder='(enter image URL here)'/>
          </div>
        </Match>
        <Match when={true}>
          <div id="attribs" class="horizontal palette" ref={attribsRef}>
            {if tool() == 'text'
              <div id="fontSizes" class="subpalette">
                <ToolCategory category="fontSize" placement="top"/>
              </div>
            else
              <div id="widths" class="subpalette">
                <ToolCategory category="width" placement="top"/>
              </div>
            }
            <div id="opacities" class="subpalette">
              <ToolCategory category="opacity" placement="top"/>
              {if opacityOn()
                <ToolCategory category="opacities" placement="top"/>
              }
            </div>
            <div id="colors" class="subpalette">
              <ToolCategory category="color" placement="top"/>
            </div>
          </div>
        </Match>
      </Switch>
    </div>
    <div id="center" class={"nopage" unless pageId()?}>
      {###touch-action="none" attribute triggers Pointer Events Polyfill (pepjs)
      ###}
      <svg id="mainBoard" class="board" touch-action="none" ref={mainBoardRef}>
        <filter id="selectFilter">
          <feGaussianBlur stdDeviation="5"/>
        </filter>
      </svg>
      <svg id="historyBoard" class="board" touch-action="none"
       ref={historyBoardRef}/>
      <svg id="remotes" class="board overlay" ref={remotesRef}/>
      <div id="dragzone" class="overlay"/>
    </div>
    {if loading()
      <LoadingIcon/>
    }
  </div>

export BadRoom = ->
  <div class="modal error">
    <h1>Invalid Room ID</h1>
    <p>Perhaps there's a typo in the URL?  It should look like this:</p>
    <pre>{Meteor.absoluteUrl 'r/gLoBaLlYuNiQuEiD7'}</pre>
    <p>Please double-check your copy/paste.</p>
    <p>Or <a href={Meteor.absoluteUrl()}>create a new room</a>.</p>
  </div>
