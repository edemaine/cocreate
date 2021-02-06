import {mainBoard, historyBoard, currentTool, currentColor, currentFill, currentFillOn} from './AppState'
import {drawingTools, tools} from './tools/tools'
import {dark, fancyCursor} from './tools/settings'
import icons from './lib/icons'

export setCursor = (target, icon, xFrac, yFrac) ->
  if fancyCursor.get()
    options = {}
    if dark.get()
      options.style = 'filter:invert(1) hue-rotate(180deg)'
    icons.setCursor target, icon, xFrac, yFrac, options
  else
    target.style.cursor = null

export updateCursor = ->
  tool = currentTool.get()
  if tool of drawingTools
    ## Drawing tools' cursors depend on the current color
    setCursor mainBoard.svg,
      drawingToolIcon(tool, currentColor.get(),
        if currentFillOn.get() then currentFill.get()),
      ...tools[tool].hotspot
  else if tool == 'history'
    setCursor historyBoard.svg,
      tools['pan'].icon, ...tools['pan'].hotspot
  else
    setCursor mainBoard.svg, tools[tool].icon, ...tools[tool].hotspot

export drawingToolIcon = (tool, color, fill) ->
  icon = tools[tool]?.icon
  return icon unless icon?
  attr = fill: color
  if tool == 'pen' or color == 'white'
    Object.assign attr,
      stroke: 'black'
      'stroke-width': '15'
      'stroke-linecap': 'round'
      'stroke-linejoin': 'round'
  icon = icons.modIcon icon, attr
  if fill and iconFill = tools[tool].iconFill
    icon = icons.stackIcons [icon, icons.modIcon iconFill, fill: fill]
  icon
