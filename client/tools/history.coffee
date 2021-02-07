import React, {useEffect, useRef, useState} from 'react'
import {useTracker} from 'meteor/react-meteor-data'

import {defineTool, tools} from './defineTool'
import {pointers} from './modes'
import {currentBoard, historyBoard, currentRoom, currentPage} from '../AppState'
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
  Slider: React.memo ->
    [diffs, setDiffs] = useState []
    {room, page} = useTracker ->
      room: currentRoom.get()
      page: currentPage.get()
    , []
    useEffect ->
      room.changeWaiting +1
      history = await meteorCallPromise 'history', room.id, page.id
      room.changeWaiting -1
      setDiffs history
      undefined
    , [room, page]

    ## Initialize range to left
    useEffect ->
      ref.current.value = 0
      undefined
    , [room, page]

    ## Set cursor
    ref = useRef()
    useEffect ->
      setCursor ref.current, tools.history.icon, ...tools.history.hotspot
      undefined
    , []

    ## Rendering
    lastTarget = useRef null
    historyRender = useRef null
    historyObjects = useRef {}
    tools.history.onChange = onChange = ->
      target = parseInt ref.current.value
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
            ## Duplicate diff to form object, to avoid clobbering by updates.
            obj = Object.assign {}, diff
            obj.pts = obj.pts[..] if obj.pts?
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

tools.history.Slider.displayName = 'tools.history.Slider'
