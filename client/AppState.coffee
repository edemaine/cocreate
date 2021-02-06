## This module maintains the global variables that represent the main app's
## current state.  This helps avoids import cycles.

import {ReactiveVar} from 'meteor/reactive-var'

export currentRoom = new ReactiveVar
export currentPage = new ReactiveVar

export currentTool = new ReactiveVar 'pan'

## These colors are initialized in ./tools/color.coffee:
export currentColor = new ReactiveVar
export currentFill = new ReactiveVar
export currentFillOn = new ReactiveVar

## Initialized in ./tools/font.coffee:
export currentFontSize = new ReactiveVar

export mainBoard = null
export historyBoard = null

export setMainBoard = (board) -> mainBoard = board
export setHistoryBoard = (board) -> historyBoard = board

export currentBoard = ->
  if currentTool.get() == 'history'
    historyBoard
  else
    mainBoard
