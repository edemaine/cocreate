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
import './opacity'
import './font'
import './color'

import {tools} from './defineTool'
export {tools}
export {toolsByCategory, toolsByHotkey} from './defineTool'

import {pointers} from './modes'
import {touchDraw} from './settings'
import {mainBoard, historyMode, currentTool} from '../AppState'
import {highlighterClear} from '../Selection'
import {updateCursor} from '../cursor'

lastDrawingTool = 'pen'

export drawingTools =
  pen: true
  segment: true
  rect: true
  ellipse: true
  text: true
export historyTools =
  pan: true
  select: true

export lastTool = null
export selectTool = (tool, options) ->
  previous = currentTool.get()
  return if tool == previous
  selected = stopTool options
  if historyMode.get() and not historyTools[tool]
    historyMode.set false
  #document.body.classList.remove "tool-#{previous}" if previous
  if tool?  # tool == null means initialize already set currentTool
    lastTool = previous
    currentTool.set tool
  else
    tool = currentTool.get()
  updateCursor()
  resumeTool options
  ## Pass previous tool's selection into new tool for possible selection.
  ## Equivalent to `setSelection` at this point because we've already cleared.
  tools[tool]?.select? selected if selected?
  #document.body.classList.add "tool-#{tool}"
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
export stopTool = (options) ->
  tools[currentTool.get()]?.stop?() unless options?.noStop
  delete pointers[key] for own key of pointers
  unless options?.noStart or options?.noStop
    ## Save previous tool's selection before clearing it
    selected = mainBoard.selection.ids()
    mainBoard.selection.clear()
    highlighterClear()
    selected

export resumeTool = (options) ->
  tools[currentTool.get()]?.start?() unless options?.noStart

export restrictTouchDraw = (e) ->
  not touchDraw.get() and
  e.pointerType == 'touch' and
  currentTool.get() of drawingTools

## Temporary tool activation, intended for excursions into 'pan' tool

export pushTool = (tool) ->
  oldTool = currentTool.get()
  oldPointers = Object.assign {}, pointers
  ## Leave existing pointer data for updating selection
  #delete pointers[key] for key of pointers
  selectTool tool, noStop: true
  {oldTool, oldPointers}

export popTool = ({oldTool, oldPointers}) ->
  selectTool oldTool, noStart: true
  ## Reset pointers to old state
  delete pointers[key] for key of pointers
  Object.assign pointers, oldPointers
  null
