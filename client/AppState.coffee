## This module maintains the global variables that represent the main app's
## current state.  This helps avoids import cycles.

import {createSignal} from 'solid-js'
import {defaultGrid, defaultGridType} from '/lib/grid'

routerNavigate = null
export setRouterNavigate = (navigate) -> routerNavigate = navigate

[currentRoom, setCurrentRoom] = createSignal()  # Room object for current room
export {currentRoom, setCurrentRoom}
[currentPage, setCurrentPage] = createSignal()  # Page object for current page
export {currentPage, setCurrentPage}
## `currentPageId` is the primary source that causes currentPage to update.
[currentPageId, setCurrentPageId] = createSignal()
export {currentPageId, setCurrentPageId}

## Use this function to change pages. It indirectly calls `setCurrentPageId`.
export gotoPageId = (id) ->
  return if id == currentPageId()
  routerNavigate "#{window.location.pathname}##{id}", replace: false

export currentGrid = ->
  currentPage()?.data()?.grid ? defaultGrid
export currentGridType = ->
  currentPage()?.data()?.gridType ? defaultGridType

[currentTool, setCurrentTool] = createSignal 'pan'
export {currentTool, setCurrentTool}
[historyMode, setHistoryMode] = createSignal false
export {historyMode, setHistoryMode}

## These colors are initialized in ./tools/color.coffee:
[currentColor, setCurrentColor] = createSignal()
export {currentColor, setCurrentColor}
[currentFill, setCurrentFill] = createSignal()
export {currentFill, setCurrentFill}
[currentFillOn, setCurrentFillOn] = createSignal()
export {currentFillOn, setCurrentFillOn}

[currentOpacity, setCurrentOpacity] = createSignal 0.5
export {currentOpacity, setCurrentOpacity}
[currentOpacityOn, setCurrentOpacityOn] = createSignal()
export {currentOpacityOn, setCurrentOpacityOn}

## Initialized in ./tools/arrow.coffee:
[currentArrowStart, setCurrentArrowStart] = createSignal()
export {currentArrowStart, setCurrentArrowStart}
[currentArrowEnd, setCurrentArrowEnd] = createSignal()
export {currentArrowEnd, setCurrentArrowEnd}

## Initialized in ./tools/dash.coffee:
[currentDash, setCurrentDash] = createSignal()
export {currentDash, setCurrentDash}

## Initialized in ./tools/width.coffee:
[currentWidth, setCurrentWidth] = createSignal()
export {currentWidth, setCurrentWidth}

## Initialized in ./tools/font.coffee:
[currentFontSize, setCurrentFontSize] = createSignal()
export {currentFontSize, setCurrentFontSize}

export mainBoard = null
export historyBoard = null

export setMainBoard = (board) -> mainBoard = board
export setHistoryBoard = (board) -> historyBoard = board

export currentBoard = ->
  if historyMode()
    historyBoard
  else
    mainBoard
