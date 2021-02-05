## Import all tools in correct order
import './undo'
import './modes'
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

import {updateCursor} from '../cursor'

export drawingTools =
  pen: true
  segment: true
  rect: true
  ellipse: true
  text: true

export currentTool = new ReactiveVar 'pan'
lastDrawingTool = 'pen'

lastTool = null
export selectTool = (tool, options) ->
  {noStart, noStop} = options if options?
  current = currentTool.get()
  if tool == current == 'history'  # treat history as a toggle
    tool = lastTool
  return if tool == current
  tools[current]?.stop? tool unless noStop
  document.body.classList.remove "tool-#{current}" if current
  if tool?  # tool == null means initialize already set currentTool
    lastTool = current
    currentTool.set tool
  updateCursor()
  pointers = {}  # tool-specific data
  tools[current]?.start?() unless noStart
  document.body.classList.add "tool-#{current}" if current
  lastDrawingTool = current if current of drawingTools

export selectDrawingTool = ->
  unless currentTool.get() of drawingTools
    selectTool lastDrawingTool
