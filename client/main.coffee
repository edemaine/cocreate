SVGNS = 'http://www.w3.org/2000/svg'

board = null  # set to svg#board element
width = 5

pressureWidth = (e) -> (0.5 + e.pressure) * width
#pressureWidth = (e) -> 2 * e.pressure * width
#pressureWidth = (e) ->
#  t = e.pressure ** 3
#  (0.5 + (1.5 - 0.5) * t) * width

eventToPoint = (e) ->
  x: e.clientX
  y: e.clientY
  w: pressureWidth e

pointerEvents = ->
  pointers = {}
  board.addEventListener 'pointerdown', (e) ->
    e.preventDefault()
    pointers[e.pointerId] = Objects.insert
      type: 'pen'
      pts: [eventToPoint e]
  board.addEventListener 'pointerup', stop = (e) ->
    e.preventDefault()
    delete pointers[e.pointerId]
  board.addEventListener 'pointerleave', stop
  board.addEventListener 'pointermove', (e) ->
    e.preventDefault()
    return unless pointers[e.pointerId]
    if e.pressure == 0
      stop e
    else
      Objects.update pointers[e.pointerId],
        $push: pts: eventToPoint e

observeRender = ->
  rendered = {}
  dot = (p) ->
    circle = document.createElementNS SVGNS, 'circle'
    circle.setAttribute 'cx', p.x
    circle.setAttribute 'cy', p.y
    circle.setAttribute 'r', p.w / 2
    board.appendChild circle
  edge = (p1, p2) ->
    line = document.createElementNS SVGNS, 'line'
    line.setAttribute 'x1', p1.x
    line.setAttribute 'y1', p1.y
    line.setAttribute 'x2', p2.x
    line.setAttribute 'y2', p2.y
    line.setAttribute 'stroke', 'black'
    line.setAttribute 'stroke-width', (p1.w + p2.w) / 2
    board.appendChild line
  Objects.find().observe
    # Currently assuming all objects are of type 'pen'
    added: (obj) ->
      rendered[obj._id] =
        for pt, i in obj.pts
          [
            edge obj.pts[i-1], pt if i > 0
            dot pt
          ]
    changed: (obj, old) ->
      # Assumes that pen changes only append to `pts` field
      r = rendered[obj._id]
      for i in [old.pts.length...obj.pts.length]
        pt = obj.pts[i]
        r.push [
          edge obj.pts[i-1], pt if i > 0
          dot pt
        ]
    removed: (obj) ->
      for elts in rendered[obj._id]
        for elt in elts when elt?
          board.removeChild elt
      delete rendered[obj._id]

Meteor.startup ->
  board = document.getElementById 'board'
  observeRender()
  pointerEvents()
