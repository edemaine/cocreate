import {defineTool, tools} from './defineTool'
import {setSelection} from './modes'
import {historyMode} from '../AppState'
import {Ctrl} from '../lib/platform'
import {undoStack} from '../UndoStack'

defineTool
  name: 'undo'
  category: 'undo'
  icon: 'undo'
  help: ->
    if historyMode()
      'Time travel back one step into the past'
    else
      'Undo the last operation you did'
  hotkey: "#{Ctrl}-Z"
  click: ->
    if historyMode()
      historyAdvance -1
    else
      setSelection undoStack.undo()

defineTool
  name: 'redo'
  category: 'undo'
  icon: 'redo'
  help: ->
    if historyMode()
      'Time travel forward one step into the future'
    else
      'Redo: Undo the last undo you did (if you did no operations since)'
  hotkey: ["#{Ctrl}-Y", "#{Ctrl}-Shift-Z"]
  click: ->
    if historyMode()
      historyAdvance +1
    else
      setSelection undoStack.redo()

historyAdvance = (delta) ->
  range = document.getElementById 'historyRange'
  value = parseInt range.value
  range.value = value + delta
  tools.history.onChange()
