## Board class maintains the top-level SVG of a board
## (the main board or the history board), including the view transformation.
## (Arguably, it should be merged with RenderObjects.)

import dom from './lib/dom'
import {Selection} from './Selection'
import {currentBoard} from './AppState'

nonrenderedClasses =
  highlight: true
  selected: true
  selector: true
  outline: true
  grid: true

## Maps a PointerEvent with `pressure` attribute to a `w` multiplier to
## multiply with the "natural" width of the pen.
pressureW = (e) -> 0.5 + e.pressure
#pressureW = (e) -> 2 * e.pressure
#pressureW = (e) ->
#  t = e.pressure ** 3
#  0.5 + (1.5 - 0.5) * t

export defaultTransform = ->
  x: 0
  y: 0
  scale: 1

export class Board
  constructor: (@svg, @readonly) ->
    @svg.appendChild @root = dom.create 'g'
    @transform = defaultTransform()
    @selection = new Selection @
    ## Page additionally sets @render to the current RenderObjects.
    ## historyBoard additionally sets @objects to mapping of ids to objects.
    ## Can't call @resize() until mainBoard gets set, after this constructor
  clear: ->
    @root.innerHTML = ''
    @setTransform {}
  destroy: ->
    @root.remove()
  resize: ->
    ## @bounding maintains client bounding box (top/left/bottom/right) of board,
    ## computed from the currently visible board (maybe not this one).
    @bounding = currentBoard().svg.getBoundingClientRect()

  findObject: (id) ->
    if @objects?  # history board
      @objects[id]
    else
      Objects.findOne id

  ## Helpers to turn events into points
  eventToPoint: (e) ->
    {x, y} = dom.svgPoint @svg, e.clientX, e.clientY, @root
    {x, y}
  eventToPointW: (e) ->
    pt = @eventToPoint e
    pt.w =
      ## iPhone (iOS 13.4, Safari 13.1) sends pressure 0 for touch events.
      ## Android Chrome (Samsung Note 8) sends pressure 1 for touch events.
      ## Just ignore pressure on touch and mouse events; could they make sense?
      if e.pointerType == 'pen'
        pressureW e
      else
        1
    pt
  eventToRawPoint: (e) ->
    x: e.clientX
    y: e.clientY
  relativePoint: (xRatio, yRatio) ->
    {x, y} = dom.svgPoint @svg,
      @bounding.left + xRatio * @bounding.width,
      @bounding.top + yRatio * @bounding.height,
      @root
    {x, y}

  ## Zoom
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
    @setTransform
      x: @transform.x + fixed.x * (1/newScale - 1/@transform.scale)
      y: @transform.y + fixed.y * (1/newScale - 1/@transform.scale)
      scale: newScale
  zoomToFit: ({minX, minY, maxX, maxY}, extra = 0.05) ->
    ## Change transform to fit on screen the rectangle bounded by (min, max),
    ## as output by renderedBBox() or dom.unionSvgBBox(), plus 5%.
    width = maxX - minX
    height = maxY - minY
    return unless width and height
    midX = 0.5 * (minX + maxX)
    midY = 0.5 * (minY + maxY)
    hScale = @bounding.width / width
    vScale = @bounding.height / height
    newScale = Math.min hScale, vScale
    newScale /= 1 + extra
    # Center the content
    targetX = midX - 0.5*@bounding.width/newScale
    targetY = midY - 0.5*@bounding.height/newScale
    @setTransform
      x: -targetX
      y: -targetY
      scale: newScale
  setScaleFixingCenter: (newScale) ->
    ###
    Maintain center point (bounding.width/2, bounding.height/2)
    ###
    @setScaleFixingPoint newScale,
      x: @bounding.width/2
      y: @bounding.height/2
  ## @transform should not be changed directly; instead, call @setTransform
  ## with any key/value pairs you want to change.  Checks for errors and
  ## triggers an update to the SVG transform attribute.
  setTransform: (newTransform) ->
    ## Check for invalid transforms before setting anything.
    for own key, value of newTransform
      unless value? and typeof value == 'number' and isFinite(value) and
             not value.toString().includes 'e'
        return console.warn "Attempt to set transform to #{JSON.stringify newTransform} with invalid #{key}"
    if newTransform.scale? and newTransform.scale <= 0
      return console.warn "Attempt to set transform to #{newTransform} with negative scale"
    ## Copy all key/values over (but allow specifying only some keys).
    for own key, value of newTransform
      @transform[key] = value
    ## Update SVG transform attribute
    @root.setAttribute 'transform',
      "scale(#{@transform.scale}) translate(#{@transform.x} #{@transform.y})"
    @onRetransform?()

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
    child for child in @renderedChildren() when @selection.has child.dataset.id
  renderedBBox: (children) ->
    dom.unionSvgBBox @svg, children, @root
