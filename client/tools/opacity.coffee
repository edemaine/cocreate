import {defineTool} from './defineTool'
import {selectDrawingTool} from './tools'
import {currentBoard, currentColor, currentOpacity, currentOpacityOn, setCurrentOpacity, setCurrentOpacityOn} from '../AppState'

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
    currentOpacityOn()
  click: ->
    setCurrentOpacityOn not currentOpacityOn()
    selection = currentBoard()?.selection
    if selection?.nonempty()
      selection.edit 'opacity',
        if currentOpacityOn()
          currentOpacity()
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
           fill={currentColor()} fill-opacity="#{opacity}"/>
        </svg>
      help: "Set opacity to #{opacity*100}% (transparency #{(1-opacity)*100}%)"
      click: -> selectOpacity opacity
      active: -> currentOpacity() == opacity

export selectOpacity = (opacity, fromSelection) ->
  setCurrentOpacity opacity
  setCurrentOpacityOn true
  return if fromSelection
  selection = currentBoard().selection
  if selection?.nonempty()
    selection.edit 'opacity', currentOpacity()
  else
    selectDrawingTool()

export selectOpacityOff = (fromSelection) ->
  setCurrentOpacityOn false
  return if fromSelection
  selection = currentBoard().selection
  if selection?.nonempty()
    selection.edit 'opacity', null
  else
    selectDrawingTool()
