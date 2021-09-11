import React from 'react'

import {defineTool} from './defineTool'
import {selectDrawingTool} from './tools'
import {currentBoard, currentColor, currentOpacity, currentOpacityOn} from '../AppState'

export opacities = [
  0.25
  0.50
  0.75
]

opacitySize = 24

defineTool
  name: 'opacity'
  category: 'width'
  icon: 'highlighter'
  help: 'Toggle partial opacity/transparency in drawings'
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

# These values are chosen for no particular reason.  I saw that
# 12.5 was a number you liked for highlighting Perhaps .25 should be 12.5
for opacity in opacities
  do (opacity) ->
    defineTool
      name: "opacity:#{opacity*100}"
      category: 'opacity'
      icon: ->
        <svg viewBox="0 0 #{opacitySize} #{opacitySize}" className="opacity"
         width={opacitySize} height={opacitySize}>
          <circle cx="#{opacitySize/2}" cy="#{opacitySize/2}" r="10"
           fill={currentColor.get()} fillOpacity="#{opacity}"/>
        </svg>
      help: "Set opacity to #{opacity*100}% (transparency #{(1-opacity)*100}%)"
      click: ->
        currentOpacity.set opacity
        selection = currentBoard().selection
        if selection?.nonempty()
          selection.edit 'opacity', currentOpacity.get()
        else
          selectDrawingTool()
      active: ->
        currentOpacity.get() == opacity

export selectOpacity = (opacity, keepTool, skipSelection) ->
  currentOpacity.set parseFloat opacity if opacity?
  if not skipSelection and (selection = currentBoard().selection)?.nonempty()
    selection.edit 'width', currentWidth.get()
    keepTool = true
  selectDrawingTool() unless keepTool
