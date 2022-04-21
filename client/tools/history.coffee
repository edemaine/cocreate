import {createEffect, createRenderEffect, createResource, on as on_, onCleanup} from 'solid-js'
import {createTracker} from 'solid-meteor-data'

import {defineTool, tools} from './defineTool'
import {selectTool, historyTools} from './tools'
import {currentPage, currentRoom, currentTool, historyBoard, historyMode, setHistoryMode} from '../AppState'
import {RenderObjects} from '../RenderObjects'
import {makeCursor} from '../cursor'
import {meteorCallPromise} from '/lib/meteorPromise'

defineTool
  name: 'history'
  category: 'mode'
  icon: 'history'
  hotspot: [0.5, 0.5]
  help: 'Time travel to the past (by dragging the bottom slider)'
  active: ->
    historyMode()
  click: ->
    setHistoryMode not historyMode()
    selectTool 'pan' unless historyTools[currentTool()]
  Slider: ->
    [diffs] = createResource (-> [currentRoom(), currentPage()]),
      ([roomVal, pageVal]) ->
        roomVal.changeWaiting +1
        try
          await meteorCallPromise 'history', roomVal.id, pageVal.id
        finally
          roomVal.changeWaiting -1
    ref = null  # range slider element

    ## Initialize range to left
    createEffect on_ [currentRoom, currentPage], ->
      ref.value = 0
    ## Clear board when entering or exiting mode and when switching pages
    lastTarget = null
    createRenderEffect on_ [currentRoom, currentPage], ->
      historyBoard.clear()
      historyBoard.objects = {}
      lastTarget = null
      onCleanup ->
        historyBoard.clear()
        historyBoard.objects = {}

    ## Rendering
    historyRender = null
    tools.history.onChange = onChange = ->
      return unless diffs()?
      target = parseInt ref.value
      ## Re-use last object set and render if just increasing in time.
      if lastTarget? and target >= lastTarget
        apply = diffs()[lastTarget...target]
      else
        historyBoard.clear()
        historyBoard.objects = {}
        historyBoard.render = historyRender = new RenderObjects historyBoard
        apply = diffs()[...target]
      return if apply.length == 0
      lastTarget = target
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
            #  historyRender.render obj,
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
            historyRender.delete diff, true
            delete historyBoard.objects[diff.id]
            toRender.delete diff.id
      for id from toRender
        historyRender.render historyBoard.objects[id]

    cursor = createTracker ->
      makeCursor tools.history.icon, ...tools.history.hotspot

    <input id="historyRange" class="history" type="range"
     min="0" max={diffs()?.length ? 0}
     title="Drag to time travel through history"
     style={
       cursor: cursor()
     }
     ref={ref} onChange={onChange}/>
