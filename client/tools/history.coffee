import React, {useEffect, useLayoutEffect, useRef, useState} from 'react'
import {useTracker} from 'meteor/react-meteor-data'

import {defineTool, tools} from './defineTool'
import {selectTool, historyTools} from './tools'
import {currentTool, historyBoard, historyMode, currentRoom, currentPage} from '../AppState'
import {RenderObjects} from '../RenderObjects'
import {setCursor} from '../cursor'
import {meteorCallPromise} from '/lib/meteorPromise'

defineTool
  name: 'history'
  category: 'mode'
  icon: 'history'
  hotspot: [0.5, 0.5]
  help: 'Time travel to the past (by dragging the bottom slider)'
  active: ->
    historyMode.get()
  click: ->
    historyMode.set not historyMode.get()
    selectTool 'pan' unless historyTools[currentTool.get()]
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
    ## Clear board when entering or exiting mode and when switching pages
    useLayoutEffect ->
      historyBoard.clear()
      historyBoard.objects = {}
      lastTarget.current = null
      ->
        historyBoard.clear()
        historyBoard.objects = {}
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
    tools.history.onChange = onChange = ->
      target = parseInt ref.current.value
      ## Re-use last object set and render if just increasing in time.
      if lastTarget.current? and target >= lastTarget.current
        apply = diffs[lastTarget...target]
      else
        historyBoard.clear()
        historyBoard.objects = {}
        historyBoard.render = historyRender.current =
          new RenderObjects historyBoard
        apply = diffs[...target]
      return if apply.length == 0
      lastTarget.current = target
      toRender = new Set
      for diff in apply
        switch diff.type
          when 'pen', 'poly', 'rect', 'ellipse', 'text', 'image'
            ## Duplicate diff to form object, to avoid clobbering by updates.
            obj = Object.assign {}, diff
            obj.pts = obj.pts[..] if obj.pts?
            historyBoard.objects[obj.id] = obj
            toRender.add obj.id
          when 'push'
            obj = historyBoard.objects[diff.id]
            obj.pts.push ...diff.pts
            toRender.add obj.id
            #unless toRender.has obj
            #  historyRender.current.render obj,
            #    start: obj.pts.length - diff.pts.length
            #    translate: false
          when 'edit'
            obj = historyBoard.objects[diff.id]
            for key, value of diff when key not in ['id', 'type']
              switch key
                when 'pts'
                  for subkey, subvalue of value
                    obj[key][subkey] = subvalue
                else
                  obj[key] = value
            toRender.add obj.id
          when 'del'
            historyRender.current.delete diff, true
            delete historyBoard.objects[diff.id]
            toRender.delete diff.id
      for id from toRender
        historyRender.current.render historyBoard.objects[id]

    <input id="historyRange" className="history" type="range"
      min="0" max={diffs.length} title="Drag to time travel through history"
      ref={ref} onChange={onChange}/>

tools.history.Slider.displayName = 'tools.history.Slider'
