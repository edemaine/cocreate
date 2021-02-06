import {defineTool} from './defineTool'
import {setSelection} from './modes'
import {currentTool} from '../AppState'
import {Ctrl} from '../lib/platform'
import {undoStack} from '../UndoStack'

defineTool
  name: 'undo'
  category: 'undo'
  icon: 'undo'
  help: 'Undo the last operation you did'
  hotkey: "#{Ctrl}-Z"
  click: ->
    if currentTool.get() == 'history'
      historyAdvance -1
    else
      setSelection undoStack.undo()

defineTool
  name: 'redo'
  category: 'undo'
  icon: 'redo'
  help: 'Redo: Undo the last undo you did (if you did no operations since)'
  hotkey: ["#{Ctrl}-Y", "#{Ctrl}-Shift-Z"]
  click: ->
    if currentTool.get() == 'history'
      historyAdvance +1
    else
      setSelection undoStack.redo()

historyAdvance = (delta) ->
  range = document.getElementById 'historyRange'
  value = parseInt range.value
  range.value = value + delta
  event = document.createEvent 'HTMLEvents'
  event.initEvent 'change', false, true
  range.dispatchEvent event
