export anchorRadius = 4
export anchorStroke = 2
#export anchorVisualRadius = anchorRadius + anchorStroke / 2
export anchorObjectTypes = new Set ['poly', 'rect', 'ellipse']

export anchorsOf = (obj) ->
  switch obj.type
    when 'poly'
      obj.pts
    when 'rect', 'ellipse'
      obj.pts.concat [
        x: obj.pts[0].x
        y: obj.pts[1].y
      ,
        x: obj.pts[1].x
        y: obj.pts[0].y
      ]
    else
      []

pointMove = (moved, index, coords) ->
  if moved[index].x == coords.x and moved[index].y == coords.y
    false
  else
    moved[index] =
      x: coords.x
      y: coords.y
    true

export anchorMove = (obj, moved, index, coords) ->
  if index > 1 and obj.type in ['rect', 'ellipse', 'image']
    if index == 2
      pointMove(moved, 0, {x: coords.x, y: moved[0].y}) or
      pointMove(moved, 1, {y: coords.y, x: moved[1].x})
    else if index == 3
      pointMove(moved, 1, {x: coords.x, y: moved[1].y}) or
      pointMove(moved, 0, {y: coords.y, x: moved[0].x})
    else
      console.error "Invalid anchor index #{index}"
  else if 0 <= index < obj.pts.length
    pointMove moved, index, coords
  else
    console.error "Out-of-bounds anchor index #{index}"

#export anchorIntersects = (point, anchor) ->
#  Math.abs(point.x - anchor.x) <= anchorVisualRadius and
#  Math.abs(point.y - anchor.y) <= anchorVisualRadius

export anchorFromEvent = (e) ->
  for elt in document.elementsFromPoint e.clientX, e.clientY
    if elt.getAttribute('class') == 'anchor'
      return elt
  return
