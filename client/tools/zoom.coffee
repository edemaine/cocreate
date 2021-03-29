import {defineTool} from './defineTool'
import {currentBoard} from '../AppState'
import {defaultTransform} from '../Board'

steppedZoom = (delta) ->
  board = currentBoard()
  return unless board?
  factor = 1.2
  log = Math.round(Math.log(board.transform.scale) / Math.log(factor))
  log += delta
  board.setScaleFixingCenter factor ** log

defineTool
  name: 'pageZoomOut'
  category: 'zoom'
  icon: 'search-minus'
  help: 'Zoom out 20%, relative to center'
  hotkey: '-'
  click: -> steppedZoom -1

defineTool
  name: 'pageZoomIn'
  category: 'zoom'
  icon: 'search-plus'
  help: 'Zoom in 20%, relative to center'
  hotkey: ['+', '=']
  click: -> steppedZoom +1

###
defineTool
  name: 'pageZoomReset'
  category: 'zoom'
  icon: 'search-one'
  help: 'Reset zoom to 100%'
  hotkey: '0'
  click: ->
    currentBoard().setScaleFixingCenter 1
###

defineTool
  name: 'pageZoomReset'
  category: 'zoom'
  icon: 'search-one'
  help: 'Reset view to the origin at 100% zoom'
  hotkey: '0'
  click: ->
    currentBoard().setTransform defaultTransform()

defineTool
  name: 'pageZoomFit'
  category: 'zoom'
  icon: 'zoom-fit'
  help: 'Zoom to fit screen to all objects or selection'
  hotkey: '9'
  click: ->
    board = currentBoard()
    ## Choose elements to contain
    if board.selection?.nonempty()
      elts = board.selectedRenderedChildren()
    else
      elts = board.renderedChildren()
    return unless elts.length
    board.zoomToFit board.renderedBBox elts
