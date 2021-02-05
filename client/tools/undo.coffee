import {Ctrl} from '../lib/platform'
import {setSelection, undoStack} from '../main'
import {defineTool} from './defineTool'

defineTool
  name: 'undo'
  category: 'undo'
  icon: 'undo'
  help: 'Undo the last operation you did'
  hotkey: "#{Ctrl}-Z"
  click: ->
    if Session.get('tool') == 'history'
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
    if Session.get('tool') == 'history'
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
