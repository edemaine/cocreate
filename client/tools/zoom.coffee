import {defineTool} from './defineTool'

defineTool
  name: 'pageZoomOut'
  category: 'zoom'
  icon: 'search-minus'
  help: 'Zoom out 20%, relative to center'
  hotkey: '-'
  click: steppedZoom = (delta = -1) ->
    factor = 1.2
    transform = currentBoard().transform
    log = Math.round(Math.log(transform.scale) / Math.log(factor))
    log += delta
    currentBoard().setScaleFixingCenter factor ** log

defineTool
  name: 'pageZoomIn'
  category: 'zoom'
  icon: 'search-plus'
  help: 'Zoom in 20%, relative to center'
  hotkey: ['+', '=']
  click: -> steppedZoom +1

defineTool
  name: 'pageZoomReset'
  category: 'zoom'
  icon: 'search-one'
  help: 'Reset zoom to 100%'
  hotkey: '0'
  click: ->
    currentBoard().setScaleFixingCenter 1

defineTool
  name: 'pageZoomFit'
  category: 'zoom'
  icon: 'zoom-fit'
  help: 'Zoom to fit screen to all objects or selection'
  hotkey: '9'
  click: ->
    ## Choose elements to contain
    if selection.nonempty() and currentBoard() == board
      elts = currentBoard().selectedRenderedChildren()
    else
      elts = currentBoard().renderedChildren()
    return unless elts.length
    currentBoard().zoomToFit currentBoard().renderedBBox elts
