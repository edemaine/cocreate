import React from 'react'
import {ReactiveVar} from 'meteor/reactive-var'

import {defineTool} from './defineTool'
import {currentBoard} from '../AppState'

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

export currentFontSize = new ReactiveVar 19

fontSizeSize = 28

for fontSize in fontSizes
  do (fontSize) ->
    defineTool
      name: "fontSize:#{fontSize}"
      category: 'fontSize'
      className: 'fontSize attrib'
      click: -> selectFontSize fontSize
      active: -> currentFontSize.get() == fontSize
      icon: -> # eslint-disable-line react/display-name
        <svg viewBox="#{-fontSizeSize/2} 0 #{fontSizeSize} #{fontSizeSize}"
         width={fontSizeSize} height={fontSizeSize}>
          <text y={fontSizeSize*0.5} style={fontSize: "#{fontSize}px"}>
            A
          </text>
          <text className="label" y={fontSizeSize*0.875}>
            {fontSize}
          </text>
        </svg>

export selectFontSize = (fontSize, skipSelection) ->
  currentFontSize.set parseFloat fontSize
  if not skipSelection and (selection = currentBoard().selection)?.nonempty()
    selection.edit 'fontSize', currentFontSize.get()
