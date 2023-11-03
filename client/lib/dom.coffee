import {BBox} from '../BBox'

export SVGNS = 'http://www.w3.org/2000/svg'

export svgTags =
  svg: true
  g: true
  line: true
  polyline: true
  rect: true
  circle: true
  ellipse: true
  text: true
  image: true

export create = (tag, attrs, props, events, children) ->
  if tag of svgTags
    elt = document.createElementNS SVGNS, tag
  else
    elt = document.createElement tag
  attr elt, attrs if attrs?
  prop elt, props if props?
  listen elt, events if events?
  elt.appendChild child for child in children if children?
  elt

export attr = (elt, attrs) ->
  if Array.isArray(elt) or elt instanceof NodeList # output of querySelectorAll
    attr sub, attrs for sub in elt when sub?
  else
    for key, value of attrs
      if value?
        elt.setAttribute key, value
      else
        elt.removeAttribute key

export prop = (elt, props) ->
  if Array.isArray elt
    prop sub, props for sub in elt when sub?
  else
    for key, value of props when value?
      if typeof value == 'object'
        prop elt[key], value
      else
        elt[key] = value

## Returns a corresponding removeEventListener callback suitable for onCleanup
export listen = (elt, events, now) ->
  if Array.isArray(elt) or elt instanceof NodeList
    callbacks =
      for sub in elt when sub?
        listen sub, events, now
    -> callback() for callback in callbacks
  else
    listeners =
      for key, value of events when value?
        value() if now
        elt.addEventListener key, value
    ->
      i = 0
      for key, value of events when value?
        elt.removeEventListener key, listeners[i++]

export classSet = (elt, key, value) ->
  if value
    elt.classList.add key
  else
    elt.classList.remove key

export classToggle = (elt, key) ->
  if elt.classList.contains key
    elt.classList.remove key
  else
    elt.classList.add key

export select = (allQuery, subQuery) ->
  for elt in document.querySelectorAll "#{allQuery}.selected"
    elt.classList.remove 'selected'
  if subQuery?
    document.querySelector "#{allQuery}#{subQuery}"
    .classList.add 'selected'

export svgPoint = (svg, x, y, matrix = svg) ->
  if matrix.getScreenCTM?
    matrix = matrix.getScreenCTM().inverse()
  pt = svg.createSVGPoint()
  pt.x = x
  pt.y = y
  pt.matrixTransform matrix

export svgTransformPoint = (svg, {x, y}, matrix) ->
  matrix = matrix.getCTM() if matrix.getCTM?
  pt = svg.createSVGPoint()
  pt.x = x
  pt.y = y
  pt.matrixTransform matrix

export svgArrowCoords = (pEnd, pAdj, width) ->
  ###
  Computes the coordinates of the two corners of an arrow head ending at pEnd,
  coming from pAdj, given a specified line width (which determines scale)
  and assuming #arrow heads.
  If pAdj has {dx, dy}, it is instead treated like a vector starting at pEnd.
  ###
  {x, y} = pEnd
  if pAdj.dx?
    {dx, dy} = pAdj
  else
    dx = pAdj.x - x
    dy = pAdj.y - y
  scale = width / Math.sqrt dx*dx + dy*dy
  dx *= scale
  dy *= scale
  px = -dy
  py = dx
  for sign in [+1, -1]
    x: x + sign * 2.4 * px + 3.8 * dx
    y: y + sign * 2.4 * py + 3.8 * dy

export svgBBox = (svg, elt, relative) ->
  ###
  Compute bounding box of element in global SVG coordinates, or coordinates of
  containing element `relative` if specified, incorporating transformations
  (assuming no rotation, so enough to look at two corners).
  Return value is of the form {min: {x: ..., y: ...}, max: {x: ..., y: ...}}
  Handling of stroke width and markers is specific to how Cocreate renders.
  ###
  box = elt.getBBox()
  transform = elt.getCTM()
  if relative?
    relative = relative.getCTM().inverse() if relative.getCTM?
    # The other should be such that parent_transform * relative_transform = transform,
    # so relative_transform = parent_transform.inverse * transform, not the other way around.
    transform = relative.multiply transform
  ## Incorporate stroke thickness to SVG's notion of bounding box.
  ## Look for stroke/markers of first child if element is a group.
  if elt.tagName == 'g'
    elt = elt.firstChild
  stroke = parseFloat elt?.getAttribute('stroke-width') ? 0
  halfStroke = stroke/2
  box = BBox.fromExtremePoints(
    svgPoint svg, box.x - halfStroke, box.y - halfStroke, transform
    svgPoint svg, box.x + halfStroke + box.width,
             box.y + halfStroke + box.height, transform
  )
  ## Incorporate markers (arrow heads) into bounding box.
  arrows = []
  if stroke and elt.points? and (len = elt.points.length) >= 2  # polyline
    if elt?.getAttribute('marker-start')?
      arrows.push ...svgArrowCoords elt.points[0], elt.points[1], stroke
    if elt?.getAttribute('marker-end')?
      arrows.push ...svgArrowCoords elt.points[len-1], elt.points[len-2], stroke
  else if stroke and elt.x1?  # <line> child of pen stroke <g>
    for l in [elt, elt.nextSibling]
      lVertex = (i) ->
        x: l["x#{i}"].baseVal.value
        y: l["y#{i}"].baseVal.value
      if l?.getAttribute('marker-start')?
        arrows.push ...svgArrowCoords lVertex(1), lVertex(2), stroke
      if l?.getAttribute('marker-end')?
        arrows.push ...svgArrowCoords lVertex(2), lVertex(1), stroke
  if arrows.length
    box = box.union BBox.fromPoints \
      (svgPoint svg, p.x, p.y, transform for p in arrows)
  box

export unionSvgBBox = (svg, elts, relative) ->
  BBox.union(
    for elt in elts
      svgBBox svg, elt, relative
  )

export pointsToRect = (p, q, epsilon = 0) ->
  x: x = Math.min p.x, q.x
  y: y = Math.min p.y, q.y
  width: (Math.max(p.x, q.x) - x) or epsilon
  height: (Math.max(p.y, q.y) - y) or epsilon

###
export pointsToSVGRect = (p, q, svg) ->
  {x, y, width, height} = pointsToRect p, q
  rect = svg.createSVGRect()
  rect.x = x
  rect.y = y
  rect.width = width
  rect.height = height
  rect
###

export escape = (text) ->
  text
  .replace /&/g, '&amp;'
  .replace /</g, '&lt;'
  .replace />/g, '&gt;'
  .replace /[ ]/g, '\u00a0'
  .replace /\t/g, '\u2003' # em-space
export unescape = (text) ->
  text
  .replace /\u2003/g, '\t'
  .replace /\u00a0/g, ' '
  .replace /&gt;/g, '>'
  .replace /&lt;/g, '<'
  .replace /&amp;/g, '&'
export escapeQuote = (text) ->
  text
  .replace /&/g, '&amp;'
  .replace /</g, '&lt;'
  .replace />/g, '&gt;'
  .replace /"/g, '&quot;'
  .replace /\n/g, '&#10;'
export unescapeQuote = (text) ->
  text
  .replace /&#10;/g, '\n'
  .replace /&quot;/g, '"'
  .replace /&gt;/g, '>'
  .replace /&lt;/g, '<'
  .replace /&amp;/g, '&'
