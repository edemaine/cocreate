SVGNS = 'http://www.w3.org/2000/svg'

board = null  # set to svg#board element
width = 5

pressureWidth = (e) -> (0.5 + e.pressure) * width
#pressureWidth = (e) -> 2 * e.pressure * width
#pressureWidth = (e) ->
#  t = e.pressure ** 3
#  (0.5 + (1.5 - 0.5) * t) * width

zeroPressureHack = false
eventToPoint = (e) ->
  ## iPhone (iOS 13.4, Safari 13.1) sends zero pressure for touch events.
  ## Fix such pressures to 0.5 (as in spec).
  w = pressureWidth e
  if zeroPressureHack
    if e.pressure == 0
      w = width
    else
      zeroPressureHack = false
  x: e.clientX
  y: e.clientY
  w: w

pointers = {}
pointerEvents = ->
  board.addEventListener 'pointerdown', (e) ->
    e.preventDefault()
    ## Assume that, if pressure initially 0, then all pressure events will be
    ## zero for this stroke.
    zeroPressureHack = (e.pressure == 0)
    pointers[e.pointerId] = Objects.insert
      room: currentRoom
      type: 'pen'
      pts: [eventToPoint e]
  board.addEventListener 'pointerup', stop = (e) ->
    e.preventDefault()
    delete pointers[e.pointerId]
  board.addEventListener 'pointerleave', stop
  board.addEventListener 'pointermove', (e) ->
    e.preventDefault()
    return unless pointers[e.pointerId]
    ## iPhone (iOS 13.4, Safari 13.1) sends zero pressure for touch events.
    #if e.pressure == 0
    #  stop e
    #else
    Objects.update pointers[e.pointerId],
      $push: pts: eventToPoint e

rendered = {}
observeRender = (room) ->
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
  Objects.find room: room
  .observe
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

currentRoom = null
roomSub = null
roomObserve = null
changeRoom = (room) ->
  return if room == currentRoom
  roomObserve?.stop()
  roomSub?.stop()
  pointers = {}
  rendered = {}
  board.innerHTML = ''
  currentRoom = room
  if room?
    roomObserve = observeRender room
    roomSub = Meteor.subscribe 'room', room

pageChange = ->
  if document.location.pathname == '/'
    room = Rooms.insert {}
    history.pushState null, 'new room', "/r/#{room}"
    pageChange()
  else if match = document.location.pathname.match /^\/r\/(\w+)$/
    changeRoom match[1]
  else
    changeRoom null

Meteor.startup ->
  board = document.getElementById 'board'
  pointerEvents()
  window.addEventListener 'popstate', pageChange
  pageChange()
