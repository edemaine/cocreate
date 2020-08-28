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
    for key, value of attrs when value?
      elt.setAttribute key, value

export prop = (elt, props) ->
  if Array.isArray elt
    prop sub, props for sub in elt when sub?
  else
    for key, value of props when value?
      if typeof value == 'object'
        prop elt[key], value
      else
        elt[key] = value

export listen = (elt, events, now) ->
  if Array.isArray elt
    listen sub, events, now for sub in elt when sub?
  else
    for key, value of events when value?
      elt.addEventListener key, value
      value() if now

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

export svgExtremes = (svg, elt) ->
  ###
  Compute bounding box of element in global SVG coordinates, incorporating
  transformations (assuming no rotation, so enough to look at two corners).
  Return value is of the form {min: {x: ..., y: ...}, max: {x: ..., y: ...}}
  ###
  bbox = elt.getBBox()
  transform = elt.getCTM()
  stroke = (parseFloat elt.getAttribute('stroke-width') ? 0) / 2
  min: svgPoint svg, bbox.x - stroke, bbox.y - stroke, transform
  max: svgPoint svg, bbox.x + stroke + bbox.width,
                     bbox.y + stroke + bbox.height, transform

export pointsToRect = (p, q) ->
  x: x = Math.min p.x, q.x
  y: y = Math.min p.y, q.y
  width: Math.max(p.x, q.x) - x
  height: Math.max(p.y, q.y) - y

export pointsToSVGRect = (p, q, svg) ->
  {x, y, width, height} = pointsToRect p, q
  rect = svg.createSVGRect()
  rect.x = x
  rect.y = y
  rect.width = width
  rect.height = height
  rect

export escape = (text) ->
  text
  .replace /&/g, '&amp;'
  .replace /</g, '&lt;'
  .replace />/g, '&gt;'
  .replace /[ ]/g, '\u00a0'
export unescape = (text) ->
  text
  .replace /&gt;/g, '>'
  .replace /&lt;/g, '<'
  .replace /&amp;/g, '&'
export escapeQuote = (text) ->
  text
  .replace /&/g, '&amp;'
  .replace /"/g, '&quot;'
export unescapeQuote = (text) ->
  text
  .replace /&quot;/g, '"'
  .replace /&amp;/g, '&'
