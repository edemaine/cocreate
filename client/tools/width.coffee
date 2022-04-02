import {ReactiveVar} from 'meteor/reactive-var'

import {defineTool} from './defineTool'
import {selectDrawingTool} from './tools'
import {currentBoard} from '../AppState'

export widths = [
  1
  2
  3
  4
  5
  6
  7
]
export currentWidth = new ReactiveVar 3

widthSize = 22

for width in widths
  do (width) ->
    defineTool
      name: "width:#{width}"
      category: 'width'
      class: 'width attrib'
      hotkey: "#{width}"
      help: "Set line width to #{width}"
      active: -> currentWidth.get() == width
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
  currentWidth.set parseFloat width
  if not skipSelection and (selection = currentBoard().selection)?.nonempty()
    selection.edit 'width', currentWidth.get()
    keepTool = true
  selectDrawingTool() unless keepTool
