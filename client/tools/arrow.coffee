import {defineTool} from './defineTool'
import {selectDrawingTool} from './tools'
import {currentBoard, currentArrowStart, setCurrentArrowStart, currentArrowEnd, setCurrentArrowEnd} from '../AppState'

arrowSize = 26

for {direction, attribute, hotkey, currentArrow, setCurrentArrow} in [
  direction: 'start'
  attribute: 'arrowStart'
  hotkey: '<'
  currentArrow: currentArrowStart
  setCurrentArrow: setCurrentArrowStart
,
  direction: 'end'
  attribute: 'arrowEnd'
  hotkey: '>'
  currentArrow: currentArrowEnd
  setCurrentArrow: setCurrentArrowEnd
]
  do (direction, attribute, hotkey, currentArrow, setCurrentArrow) ->
    defineTool
      name: "arrow:#{direction}"
      category: 'arrow'
      class: 'arrow attrib'
      hotkey: hotkey
      help: "Toggle arrow at #{direction} of line segments"
      active: -> Boolean currentArrow()
      click: ->
        setCurrentArrow if currentArrow() then null else 'arrow'
        if (selection = currentBoard().selection)?.nonempty()
          selection.edit attribute, currentArrow()
        else
          selectDrawingTool()
      icon: ->
        <svg viewBox="#{-arrowSize} #{-arrowSize/2} #{arrowSize} #{arrowSize}"
         width={arrowSize} height={arrowSize}
         transform={'rotate(180)' if direction == 'start'}>
          <line x1={-22} x2={-4} stroke="black" stroke-width={3}
           stroke-linecap="round" marker-end="url(#arrow)"/>
        </svg>
