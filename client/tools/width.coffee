import {defineTool} from './defineTool'
import {selectDrawingTool} from './tools'
import {currentBoard, currentWidth, setCurrentWidth} from '../AppState'

export widths = [
  1
  2
  3
  4
  5
  6
  7
]
setCurrentWidth 3

widthSize = 22

for width in widths
  do (width) ->
    defineTool
      name: "width:#{width}"
      category: 'width'
      class: 'width attrib'
      hotkey: "#{width}"
      help: "Set line width to #{width}"
      active: -> currentWidth() == width
      click: -> selectWidth width
      icon: ->
        <svg viewBox="0 #{-widthSize/3} #{widthSize} #{widthSize}"
         width={widthSize} height={widthSize}>
          <line x2={widthSize} stroke-width={width}/>
          <text class="label" x={widthSize/2} y={widthSize*2/3}>
            {width}
          </text>
        </svg>

export selectWidth = (width, keepTool, skipSelection) ->
  setCurrentWidth parseFloat width
  if not skipSelection and (selection = currentBoard().selection)?.nonempty()
    selection.edit 'width', currentWidth()
    keepTool = true
  selectDrawingTool() unless keepTool
