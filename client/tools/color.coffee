import {createEffect, createSignal} from 'solid-js'

import {defineTool} from './defineTool'
import {selectDrawingTool} from './tools'
import {currentBoard, currentColor, currentFill, currentFillOn, setCurrentColor, setCurrentFill, setCurrentFillOn} from '../AppState'
import {updateCursor} from '../cursor'
import icons from '../lib/icons'

export colors = [
  'black'   # Windows Journal black
  '#666666' # Windows Journal grey
  '#989898' # medium grey
  '#bbbbbb' # lighter grey
  'white'
  '#333399' # Windows Journal dark blue
  '#3366ff' # Windows Journal light blue
  '#00c7c7' # custom light cyan
  '#008000' # Windows Journal green
  '#00c000' # lighter green
  '#800080' # Windows Journal purple
  '#d000d0' # lighter magenta
  '#a00000' # darker red
  '#ff0000' # Windows Journal red
  '#855723' # custom brown
  #'#ff9900' # Windows Journal orange
  '#ed8e00' # custom orange
  '#eced00' # custom yellow
]

export defaultColor = 'black'
setCurrentColor defaultColor
setCurrentFill 'white'
setCurrentFillOn false

export colorMap = {}
colorMap[color] = true for color in colors

createEffect ->
  document.documentElement.style.setProperty '--currentColor', currentColor()

defineTool
  name: 'fill'
  category: 'color'
  help: <>Toggle filling of rectangles and ellipses. <kbd>Shift</kbd>-click a color to set fill color.</>
  active: -> currentFillOn()
  icon: ->
    if currentFillOn()
      icons.modIcon 'tint', fill: currentFill()
    else
      icons.modIcon 'tint-slash', fill: currentFill()
  click: ->
    setCurrentFillOn not currentFillOn()
    selection = currentBoard()?.selection
    if selection?.nonempty()
      selection.edit 'fill',
        if currentFillOn()
          currentFill()
        else
          null
    else
      selectDrawingTool()

for color in colors
  do (color) ->
    defineTool
      name: "color:#{color}"
      category: 'color'
      class: 'attrib'
      active: -> currentColor() == color
      icon: ->
        <div class="color" style={'background-color': color}/>
      click: (e) -> selectColorOrFill e, color

[customColor, setCustomColor] = createSignal '#808080'

defineTool
  name: 'customColor'
  category: 'color'
  class: 'attrib'
  help: <>Custom colors. Select the rainbow icon to change the custom color (via browser-specific color selector). Select the colored outer rim to re-use the previously chosen color. Use the Select tool to grab colors from existing objects.</>
  active: -> currentColor() == customColor()
  icon: ->
    customColorRef = null
    onSet = (e) ->
      e.stopPropagation()
      customColorRef.querySelector('input').click()
    onInput = (e) ->
      selectColor e.target.value
    <div class="custom color" style={'background-color': customColor()}
     ref={customColorRef}>
      <div class="set" onClick={onSet}/>
      <input type="color" onInput={onInput} value={customColor()}/>
    </div>
  click: (e) ->
    selectColorOrFill e, customColor()

selectColorOrFill = (e, color) ->
  (if e.shiftKey then selectFill else selectColor) color

export selectColor = (color, keepTool, skipSelection) ->
  setCurrentColor color
  setCustomColor color unless color of colorMap
  if not skipSelection and (selection = currentBoard().selection).nonempty()
    selection.edit 'color', currentColor()
    keepTool = true
  selectDrawingTool() unless keepTool
  updateCursor()

export selectFill = (color, fromSelection) ->
  setCurrentFill color
  setCurrentFillOn true
  return if fromSelection
  selection = currentBoard().selection
  if selection?.nonempty()
    selection.edit 'fill', currentFill()
  else
    selectDrawingTool()

export selectFillOff = (fromSelection) ->
  setCurrentFillOn false
  return if fromSelection
  selection = currentBoard().selection
  if selection?.nonempty()
    selection.edit 'fill', null
  else
    selectDrawingTool()
