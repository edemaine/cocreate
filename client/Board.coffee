## Board class maintains the top-level SVG of a board
## (the main board or the history board), including the view transformation.
## (Arguably, it should be merged with RenderObjects.)

import dom from './lib/dom'
import {currentBoard, selection} from './main'

nonrenderedClasses =
  highlight: true
  selected: true
  outline: true
  grid: true

export class Board
  constructor: (domId) ->
    @svg = document.getElementById domId
    @svg.appendChild @root = dom.create 'g'
    @transform =
      x: 0
      y: 0
      scale: 1
  resize: ->
    ## @bbox maintains client bounding box (top/left/bottom/right) of board,
    ## computed from the currently visible board (maybe not this one).
    @bbox = currentBoard().svg.getBoundingClientRect()
    @remotesRender?.resize()
    @grid?.update()
  setScaleFixingPoint: (newScale, fixed) ->
    ###
    Transform point (x,y) while preserving (fixed.x, fixed.y):
      fixed.x = (x + transform.x) * transform.scale
        => x = fixed.x / transform.scale - transform.x
      fixed.x = (x + newX) * newScale
        => newX = fixed.x / newScale - x
         = fixed.x / newScale - fixed.x / transform.scale + transform.x
         = fixed.x * (1 / newScale - 1 / transform.scale) + transform.x
    ###
    @transform.x += fixed.x * (1/newScale - 1/@transform.scale)
    @transform.y += fixed.y * (1/newScale - 1/@transform.scale)
    @transform.scale = newScale
    @retransform()
  zoomToFit: ({min, max}, extra = 0.05) ->
    ## Change transform to fit on screen the rectangle bounded by (min, max),
    ## as output by renderedBBox() or dom.unionSvgExtremes(), plus 5%.
    width = max.x - min.x
    height = max.y - min.y
    return unless width and height
    midx = 0.5 * (min.x + max.x)
    midy = 0.5 * (min.y + max.y)
    hScale = @bbox.width / width
    vScale = @bbox.height / height
    newScale = Math.min hScale, vScale
    newScale /= 1 + extra
    # Center the content
    targetx = midx - 0.5*@bbox.width/newScale
    targety = midy - 0.5*@bbox.height/newScale
    @transform.x = -targetx
    @transform.y = -targety
    @transform.scale = newScale
    @retransform()
  setScaleFixingCenter: (newScale) ->
    ###
    Maintain center point (bbox.width/2, bbox.height/2)
    ###
    @setScaleFixingPoint newScale,
      x: @bbox.width/2
      y: @bbox.height/2
  retransform: ->
    @root.setAttribute 'transform',
      "scale(#{@transform.scale}) translate(#{@transform.x} #{@transform.y})"
    @remotesRender?.retransform()
    ## Update grid after `transform` attribute gets rendered.
    Meteor.setTimeout =>
      @grid?.update()
    , 0
  renderedChildren: ->
    for child in @root.childNodes
      skip = false
      for className in child.classList
        if className of nonrenderedClasses
          skip = true
          break
      continue if skip
      child
  selectedRenderedChildren: ->
    child for child in @renderedChildren() when selection.has child.dataset.id
  renderedBBox: (children) ->
    dom.unionSvgExtremes @svg, children, @root
  clear: ->
    @root.innerHTML = ''
