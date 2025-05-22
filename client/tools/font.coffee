import {createSignal, createEffect, createMemo, onCleanup} from 'solid-js'
import debounce from 'debounce'

import {defineTool} from './defineTool'
import {currentBoard, currentFontSize, setCurrentFontSize, currentFontSizeOn, setCurrentFontSizeOn} from '../AppState'
import {gridSize} from '../Grid'

import dom from '../lib/dom'

## By default, round font sizes to powers of 1.2 starting from 16
## (the site's default font size)

## Manually specify which font sizes +/- buttons snap to
## (larger values are calculated automatically)
smallFontSizes = [
  8
  10
  12
  14
  16
]

## To calculate larger font size values
fontSizeBase = smallFontSizes[smallFontSizes.length-1]
fontSizeExponent = 1.2

## Original default was 19
setCurrentFontSize 28
setCurrentFontSizeOn false

## Size of the tool icon
fontSizeSize = 28

lineColor = createMemo -> if currentFontSizeOn() then "#70c5f3" else "#60b0dc"

## Font size display (also functioning as input toggle button)
defineTool
  name: "fontSize:edit"
  category: 'fontSize'
  class: 'fontSize attrib'
  click: -> setCurrentFontSizeOn not currentFontSizeOn()
  active: -> currentFontSizeOn()
  icon: ->
    ## mousedown listener is a hack to allow clicking to toggle
    ## https://stackoverflow.com/questions/17769005/onclick-and-onblur-ordering-issue
    <svg viewBox="#{-fontSizeSize/2} 0 #{fontSizeSize} #{fontSizeSize}"
      width={fontSizeSize} height={fontSizeSize}
      onMouseDown={(e) -> e.preventDefault()}
    >
      <g style={
        'stroke-width': 1
        'stroke': if currentFontSizeOn() then "#94d9ff" else "#60b0dc"
      }>
        <line
          x1={fontSizeSize*-0.22} y1={fontSizeSize*0}
          x2={fontSizeSize*-0.22} y2={fontSizeSize*0.8}
        ></line>
        <line
          x1={fontSizeSize*0.22} y1={fontSizeSize*0}
          x2={fontSizeSize*0.22} y2={fontSizeSize*0.8}
        ></line>
        <line
          x1={fontSizeSize*-0.5} y1={fontSizeSize*0.1}
          x2={fontSizeSize*0.5} y2={fontSizeSize*0.1}
        ></line>
        <line
          x1={fontSizeSize*-0.5} y1={fontSizeSize*0.54}
          x2={fontSizeSize*0.5} y2={fontSizeSize*0.54}
        ></line>
      </g>
      <text y={fontSizeSize*0.5} style={'font-size': "#{currentFontSize() * (fontSizeSize*0.44)/gridSize}px"}>
        A
      </text>
      <text class="label" y={fontSizeSize*0.875}>
        {currentFontSize() unless currentFontSizeOn()}
      </text>
    </svg>

## Increase/decrease font size buttons
buttons = [
    symbol: '-'
    click: -> selectFontSize smallerFont(currentFontSize())
    iconSize: 12
    help: <>Decrease the current font size.</>
  ,
    symbol: '+'
    click: -> selectFontSize biggerFont(currentFontSize())
    iconSize: 24
    help: <>Increase the current font size.</>
]
for {symbol, click, iconSize, help} in buttons
  do (symbol, click, iconSize, help) ->
    defineTool
      name: "fontSize:change#{symbol}"
      category: 'fontSizeButtons'
      class: 'fontSize attrib'
      help: help
      click: click
      icon: ->
        <svg viewBox="#{-fontSizeSize/2} 0 #{fontSizeSize} #{fontSizeSize}"
          width={fontSizeSize} height={fontSizeSize}>
          <text y={fontSizeSize*0.5} style={'font-size': "16px", 'fill': "gray"}>
            A
          </text>
          <text y={fontSizeSize*0.5} style={'font-size': "#{iconSize}px"}>
            A
          </text>
          <text class="label" y={fontSizeSize*0.875}>
            {symbol}
          </text>
        </svg>

## Font size text input handler
createEffect ->
  return unless currentFontSizeOn()
  input = document.getElementById 'fontSizeInput'
  return unless input?
  input.value = ''
  input.focus()
  input.className = ''
  onCleanup dom.listen input,
    keydown: (e) ->
      e.stopPropagation() # avoid hotkeys
      e.target.blur() if e.key == 'Escape'
      updateFontSize e if e.key == 'Enter'  # check/submit custom font size
    input: (e) ->
      input.className = 'pending'
    change: updateFontSize = debounce (e) ->
      newFontSize = parseFloat e.target.value
      setCurrentFontSize newFontSize unless (isNaN newFontSize) or (newFontSize <= 0)
      setCurrentFontSizeOn false
    , 50
    blur: -> setCurrentFontSizeOn false

## Given a font size, determine the new size after increase/decrease buttons
biggerFont = (fontSize) ->
  if fontSize < fontSizeBase
    for size in smallFontSizes
      return size if size > fontSize

  fontSizeLog = Math.log(fontSize / fontSizeBase) / Math.log(fontSizeExponent)
  newFontSize = fontSizeBase * fontSizeExponent ** Math.ceil(fontSizeLog)
  newFontSize *= fontSizeExponent unless Math.round(newFontSize) > fontSize
  
  Math.round(newFontSize)

smallerFont = (fontSize) ->
  if fontSize <= fontSizeBase
    for size in smallFontSizes by -1
      return size if size < fontSize
    return fontSize

  fontSizeLog = Math.log(fontSize / fontSizeBase) / Math.log(fontSizeExponent)
  newFontSize = fontSizeBase * fontSizeExponent ** Math.floor(fontSizeLog)
  newFontSize /= fontSizeExponent unless Math.round(newFontSize) < fontSize

  Math.round(newFontSize)

export selectFontSize = (fontSize, skipSelection) ->
  setCurrentFontSize parseFloat fontSize
  if not skipSelection and (selection = currentBoard().selection)?.nonempty()
    selection.edit 'fontSize', currentFontSize()
