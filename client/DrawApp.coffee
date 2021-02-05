import React, {useEffect, useRef} from 'react'
import {useParams} from 'react-router-dom'
import {useTracker} from 'meteor/react-meteor-data'

import {Board} from './Board'
import {Loading} from './Loading'
import {Name} from './Name'
import {Room} from './Room'
import {ToolCategory} from './Tool'
import {currentTool} from './tools/tools'
import {useHorizontalScroll} from './lib/hscroll'

export currentRoom = new ReactiveVar
export mainBoard = null
export historyBoard = null

export currentBoard = ->
  if currentTool.get() == 'history'
    historyBoard
  else
    mainBoard

export DrawApp = React.memo ->
  ## Create Board and Room data structures
  {roomId} = useParams()
  mainBoardRef = useRef()
  historyBoardRef = useRef()
  remotesRef = useRef()
  useEffect ->
    mainBoard = new Board mainBoardRef.current
    historyBoard = new Board historyBoardRef.current
    onResize()
    currentRoom.set new Room roomId, mainBoard
    ->
      currentRoom.get().stop()
      currentRoom.set null
      historyBoard.destroy()
      mainBoard.destroy()
  , [roomId]
  onResize = ->
    mainBoard?.resize()
    historyBoard?.resize()
  useEffect ->
    window.addEventListener 'resize', onResize
    -> window.removeEventListener onResize
  , []

  ## Test for whether room is loading and/or bad
  room = useTracker ->
    currentRoom.get()
  , []
  {loading, bad} = useTracker ->
    return {} unless room?
    loading: room.loading()
    bad: room.bad()
  , [room]

  ## Page info
  {pageNum, numPages} = useTracker ->
    numPages: room?.numPages() ? '?'
    pageNum: room?.pageIndex() ? '?'
  , [room]
  pageNum++ if typeof pageNum == 'number'

  tool = useTracker ->
    currentTool.get()
  , []

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
      <div id="pageNumbers">
        {'page '}
        <input id="pageNum" type="text" value={pageNum}/>
        {' of '}
        <span id="numPages">{numPages}</span>
      </div>
      <ToolCategory category="page" placement="bottom"/>
      <ToolCategory category="zoom" placement="bottom"/>
      <div className="spacer"/>
      <Name/>
    </div>
    <div id="bottom" className="horizontal super palette">
      {if tool == 'text'
        <div id="text" className="horizontal palette">
          <textarea id="textInput" type="text" placeholder='(type text here)'/>
        </div>
      }
      {if tool == 'history'
        <div id="history" className="horizontal palette">
          <input id="historyRange" className="history" type="range" min="0" max="0" title="Drag to time travel through history"/>
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
    <div id="center">
      {###touch-action="none" attribute triggers Pointer Events Polyfill (pepjs)
       ###}
      <svg id="mainBoard" className="board historyHide" touch-action="none"
       ref={mainBoardRef}>
        <filter id="selectFilter">
          <feGaussianBlur stdDeviation="5"/>
        </filter>
      </svg>
      <svg id="historyBoard" className="board historyShow" touch-action="none"
       ref={historyBoardRef}/>
      <svg id="remotes" className="board overlay historyHide"
       ref={remotesRef}/>
      <div id="dragzone" className="overlay"/>
    </div>
    {if loading
      <Loading/>
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
