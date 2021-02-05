import React, {useEffect, useRef, useState} from 'react'

import {defineTool} from './defineTool'
import {pointers} from './modes'
import {tools} from './tools'
import {currentBoard, historyBoard, currentRoom, currentPage} from '../DrawApp'
import {RenderObjects} from '../RenderObjects'
import {setCursor} from '../cursor'
import {meteorCallPromise} from '/lib/meteorPromise'

defineTool
  name: 'history'
  category: 'mode'
  icon: 'history'
  hotspot: [0.5, 0.5]
  help: 'Time travel to the past (by dragging the bottom slider)'
  start: ->
    ## Handled by HistorySlider
  stop: ->
    document.getElementById('historyRange').removeEventListener 'change', pointers.listen
    historyBoard.clear()
  down: (e) ->
    pointers[e.pointerId] = currentBoard().eventToRawPoint e
    pointers[e.pointerId].transform =
      Object.assign {}, historyBoard.transform
  up: (e) ->
    delete pointers[e.pointerId]
  move: (e) ->
    return unless start = pointers[e.pointerId]
    current = currentBoard().eventToRawPoint e
    historyBoard.transform.x = start.transform.x +
      (current.x - start.x) / historyBoard.transform.scale
    historyBoard.transform.y = start.transform.y +
      (current.y - start.y) / historyBoard.transform.scale
    historyBoard.retransform()

export HistorySlider = React.memo ->
  [diffs, setDiffs] = useState []
  useEffect ->
    currentRoom.get().changeWaiting +1
    history = await meteorCallPromise 'history',
      currentRoom.get().id, currentPage.get().id
    currentRoom.get().changeWaiting -1
    setDiffs history
    undefined
  , []

  ## Set cursor
  ref = useRef()
  useEffect ->
    setCursor ref.current, tools.history.icon, ...tools.history.hotspot
    undefined
  , []

  ## Initialize range to left
  useEffect ->
    ref.current.value = 0
    undefined
  , []

  ## Rendering
  lastTarget = useRef null
  historyRender = useRef null
  historyObjects = useRef {}
  onChange = (e) ->
    target = parseInt e.target.value
    ## Re-use last object set and render if just increasing in time.
    if lastTarget.current? and target >= lastTarget.current
      apply = diffs[lastTarget...target]
    else
      historyBoard.clear()
      historyBoard.retransform()
      historyObjects.current = {}
      historyRender.current = new RenderObjects historyBoard
      apply = diffs[...target]
    return if apply.length == 0
    lastTarget.current = target
    for diff in apply
      switch diff.type
        when 'pen', 'poly', 'rect', 'ellipse', 'text', 'image'
          obj = diff
          historyObjects.current[obj.id] = obj
          historyRender.current.render obj
        when 'push'
          obj = historyObjects.current[diff.id]
          obj.pts.push ...diff.pts
          historyRender.current.render obj,
            start: obj.pts.length - diff.pts.length
            translate: false
        when 'edit'
          obj = historyObjects.current[diff.id]
          for key, value of diff when key not in ['id', 'type']
            switch key
              when 'pts'
                for subkey, subvalue of value
                  obj[key][subkey] = subvalue
              else
                obj[key] = value
          historyRender.current.render obj
        when 'del'
          historyRender.current.delete diff
          delete historyObjects.current[diff.id]

  <input id="historyRange" className="history" type="range"
    min="0" max={diffs.length} title="Drag to time travel through history"
    ref={ref} onChange={onChange}/>
HistorySlider.displayName = 'HistorySlider'
