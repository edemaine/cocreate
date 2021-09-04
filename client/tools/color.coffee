import React from 'react'
import {Tracker} from 'meteor/tracker'
import {ReactiveVar} from 'meteor/reactive-var'

import {defineTool} from './defineTool'
import {selectDrawingTool} from './tools'
import {currentBoard, currentColor, currentFill, currentFillOn} from '../AppState'
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
currentColor.set defaultColor
currentFill.set 'white'
currentFillOn.set false

export colorMap = {}
colorMap[color] = true for color in colors

Tracker.autorun ->
  document.documentElement.style.setProperty '--currentColor',
    currentColor.get()

defineTool
  name: 'fill'
  category: 'color'
  help: <>Toggle filling of rectangles and ellipses. <kbd>Shift</kbd>-click a color to set fill color.</>
  active: -> currentFillOn.get()
  icon: -> # eslint-disable-line react/display-name
    if currentFillOn.get()
      icons.modIcon 'tint', fill: currentFill.get()
    else
      icons.modIcon 'tint-slash', fill: currentFill.get()
  click: ->
    currentFillOn.set not currentFillOn.get()
    selection = currentBoard()?.selection
    if selection?.nonempty()
      selection.edit 'fill',
        if currentFillOn.get()
          currentFill.get()
        else
          null
    else
      selectDrawingTool()

for color in colors
  do (color) ->
    defineTool
      name: "color:#{color}"
      category: 'color'
      className: 'attrib'
      active: -> currentColor.get() == color
      icon: -> # eslint-disable-line react/display-name
        <div className="color" style={backgroundColor: color}/>
      click: (e) ->
        selectColorOrFill e, color
        updateColorOpacity()

customColor = new ReactiveVar '#808080'
customColorRef = React.createRef()

defineTool
  name: 'customColor'
  category: 'color'
  className: 'attrib'
  help: <>Custom colors. Select the rainbow icon to change the custom color (via browser-specific color selector). Select the colored outer rim to re-use the previously chosen color. Use the Select tool to grab colors from existing objects.</>
  active: -> currentColor.get() == customColor.get()
  icon: -> # eslint-disable-line react/display-name
    onSet = (e) ->
      e.stopPropagation()
      customColorRef.current.querySelector('input').click()
    onInput = (e) ->
      selectColor e.target.value
    color = customColor.get()
    <div className="custom color" style={backgroundColor: color}
     ref={customColorRef}>
      <div className="set" onClick={onSet}/>
      <input type="color" onInput={onInput} value={color}/>
    </div>
  click: (e) ->
    selectColorOrFill e, customColor.get()

selectColorOrFill = (e, color) ->
  (if e.shiftKey then selectFill else selectColor) color

export selectColor = (color, keepTool, skipSelection) ->
  currentColor.set color
  customColor.set color unless color of colorMap
  if not skipSelection and (selection = currentBoard().selection).nonempty()
    selection.edit 'color', currentColor.get()
    keepTool = true
  selectDrawingTool() unless keepTool
  updateCursor()

export selectFill = (color, fromSelection) ->
  currentFill.set color
  currentFillOn.set true
  return if fromSelection
  selection = currentBoard().selection
  if selection?.nonempty()
    selection.edit 'fill', currentFill.get()
  else
    selectDrawingTool()

export selectFillOff = ->
  currentFillOn.set false
  selection = currentBoard().selection
  if selection?.nonempty()
    selection.edit 'fill', null
  else
    selectDrawingTool()

updateColorOpacity = () ->
  for el in document.querySelectorAll('[data-tool^="Opacity"]')
    el.style.fill = currentColor.get()