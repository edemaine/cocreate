import {defineTool} from './defineTool'
import {currentBoard, currentFontSize, setCurrentFontSize} from '../AppState'

## These numbers are based on powers of 1.2 starting from 16
## (the site's default font size)
export fontSizes = [
  12
  16
  19
  23
  28
  33
  40
]

setCurrentFontSize 19

fontSizeSize = 28

for fontSize in fontSizes
  do (fontSize) ->
    defineTool
      name: "fontSize:#{fontSize}"
      category: 'fontSize'
      class: 'fontSize attrib'
      click: -> selectFontSize fontSize
      active: -> currentFontSize() == fontSize
      icon: ->
        <svg viewBox="#{-fontSizeSize/2} 0 #{fontSizeSize} #{fontSizeSize}"
         width={fontSizeSize} height={fontSizeSize}>
          <text y={fontSizeSize*0.5} style={'font-size': "#{fontSize}px"}>
            A
          </text>
          <text class="label" y={fontSizeSize*0.875}>
            {fontSize}
          </text>
        </svg>

export selectFontSize = (fontSize, skipSelection) ->
  setCurrentFontSize parseFloat fontSize
  if not skipSelection and (selection = currentBoard().selection)?.nonempty()
    selection.edit 'fontSize', currentFontSize()
