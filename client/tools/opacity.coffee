import {defineTool} from './defineTool'
import {selectDrawingTool} from './tools'
import {currentBoard, currentColor, currentOpacity, currentOpacityOn} from '../AppState'

export opacities = [
  0.25
  0.50
  0.75
]

opacitySize = 24
opacityRadius = 9

defineTool
  name: 'opacity'
  category: 'opacity'
  icon: 'highlighter'
  help: 'Toggle partial opacity / transparency in objects'
  active: ->
    currentOpacityOn.get()
  click: ->
    currentOpacityOn.set not currentOpacityOn.get()
    selection = currentBoard()?.selection
    if selection?.nonempty()
      selection.edit 'opacity',
        if currentOpacityOn.get()
          currentOpacity.get()
        else
          null
    else
      selectDrawingTool()

for opacity in opacities
  do (opacity) ->
    defineTool
      name: "opacity:#{opacity*100}"
      category: 'opacities'
      icon: ->
        <svg viewBox="-#{opacitySize/2} -#{opacitySize/2} #{opacitySize} #{opacitySize}"
         class="opacity" width={opacitySize} height={opacitySize}>
          <circle r={opacityRadius}
           fill={currentColor.get()} fill-opacity="#{opacity}"/>
        </svg>
      help: "Set opacity to #{opacity*100}% (transparency #{(1-opacity)*100}%)"
      click: -> selectOpacity opacity
      active: -> currentOpacity.get() == opacity

export selectOpacity = (opacity, fromSelection) ->
  currentOpacity.set opacity
  currentOpacityOn.set true
  return if fromSelection
  selection = currentBoard().selection
  if selection?.nonempty()
    selection.edit 'opacity', currentOpacity.get()
  else
    selectDrawingTool()

export selectOpacityOff = (fromSelection) ->
  currentOpacityOn.set false
  return if fromSelection
  selection = currentBoard().selection
  if selection?.nonempty()
    selection.edit 'opacity', null
  else
    selectDrawingTool()
