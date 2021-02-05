### eslint-disable import/no-duplicates ###

## Import all tools in correct order
import './undo'
import './modes'
import './history'
import './room'
import './download'
import './settings'
import './links'
import './page'
import './zoom'
import './width'
import './font'
import './color'

import {tools} from './defineTool'
export {tools}
export {toolsByCategory, toolsByHotkey} from './defineTool'
export {HistorySlider} from './history'

import {ReactiveVar} from 'meteor/reactive-var'

import {pointers} from './modes'
import {allowTouch} from './settings'
import {updateCursor} from '../cursor'

export currentTool = new ReactiveVar 'pan'
lastDrawingTool = 'pen'

export drawingTools =
  pen: true
  segment: true
  rect: true
  ellipse: true
  text: true

export lastTool = null
export selectTool = (tool, options) ->
  {noStart, noStop} = options if options?
  previous = currentTool.get()
  if tool == previous == 'history'  # treat history as a toggle
    tool = lastTool
  return if tool == previous
  stopTool() unless noStop
  document.body.classList.remove "tool-#{previous}" if previous
  if tool?  # tool == null means initialize already set currentTool
    lastTool = previous
    currentTool.set tool
  updateCursor()
  tools[tool]?.start?() unless noStart
  document.body.classList.add "tool-#{tool}" if tool
  lastDrawingTool = tool if tool of drawingTools

export selectDrawingTool = ->
  unless currentTool.get() of drawingTools
    selectTool lastDrawingTool

export clickTool = (toolSpec, e) ->
  return unless toolSpec?
  if toolSpec.click?
    toolSpec.click e
  else
    selectTool toolSpec.name

## Stop current tool, but keep currentTool set, so that it can be resumed
## with `resumeTool` (e.g. when switching pages).
export stopTool = ->
  tools[currentTool.get()]?.stop?()
  delete pointers[key] for own key of pointers

export resumeTool = ->
  selectTool null

export restrictTouch = (e) ->
  not allowTouch.get() and \
  e.pointerType == 'touch' and \
  currentTool.get() of drawingTools
