SVGNS = 'http://www.w3.org/2000/svg'

colors = [
  'black'
  '#666666'
  '#333399'
  '#3366ff'
  '#008000'
  '#800080'
  '#c700c7'
  '#ff0000'
  '#ff9900'
  'white'
]
colorDivs = null
currentColor = 'black'

board = null    # set to svg#board element
boardBB = null  # bounding box (top/left/bottom/right) of board
width = 5

pressureWidth = (e) -> (0.5 + e.pressure) * width
#pressureWidth = (e) -> 2 * e.pressure * width
#pressureWidth = (e) ->
#  t = e.pressure ** 3
#  (0.5 + (1.5 - 0.5) * t) * width

eventToPoint = (e) ->
  x: e.clientX - boardBB.left
  y: e.clientY - boardBB.top
  w:
    ## iPhone (iOS 13.4, Safari 13.1) sends pressure 0 for touch events.
    ## Android Chrome (Samsung Note 8) sends pressure 1 for touch events.
    ## Just ignore pressure on touch and mouse events; could they make sense?
    if e.pointerType == 'pen'
      w = pressureWidth e
    else
      w = width

pointers = {}
pointerEvents = ->
  board.addEventListener 'pointerdown', down = (e) ->
    e.preventDefault()
    pointers[e.pointerId] = Objects.insert
      room: currentRoom
      type: 'pen'
      pts: [eventToPoint e]
      color: currentColor
  board.addEventListener 'pointerenter', (e) ->
    down e if e.buttons
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
  dot = (obj, p) ->
    circle = document.createElementNS SVGNS, 'circle'
    circle.setAttribute 'cx', p.x
    circle.setAttribute 'cy', p.y
    circle.setAttribute 'r', p.w / 2
    circle.setAttribute 'fill', obj.color
    board.appendChild circle
  edge = (obj, p1, p2) ->
    line = document.createElementNS SVGNS, 'line'
    line.setAttribute 'x1', p1.x
    line.setAttribute 'y1', p1.y
    line.setAttribute 'x2', p2.x
    line.setAttribute 'y2', p2.y
    line.setAttribute 'stroke', obj.color
    line.setAttribute 'stroke-width', (p1.w + p2.w) / 2
    # Lines mode:
    #line.setAttribute 'stroke-width', 1
    board.appendChild line
  Objects.find room: room
  .observe
    # Currently assuming all objects are of type 'pen'
    added: (obj) ->
      rendered[obj._id] =
        for pt, i in obj.pts
          [
            edge obj, obj.pts[i-1], pt if i > 0
            dot obj, pt
          ]
    changed: (obj, old) ->
      # Assumes that pen changes only append to `pts` field
      r = rendered[obj._id]
      for i in [old.pts.length...obj.pts.length]
        pt = obj.pts[i]
        r.push [
          edge obj, obj.pts[i-1], pt if i > 0
          dot obj, pt
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

paletteColors = ->
  colorsDiv = document.getElementById 'colors'
  colorDivs =
    for color in colors
      do (color) ->
        colorDiv = document.createElement 'div'
        colorDiv.className = 'color'
        colorDiv.style.backgroundColor = color
        colorDiv.addEventListener 'click', -> selectColor color
        colorsDiv.appendChild colorDiv
        colorDiv

selectColor = (color) ->
  currentColor = color if color?
  for div in document.querySelectorAll '.color.selected'
    div.classList.remove 'selected'
  colorDivs[colors.indexOf currentColor].classList.add 'selected'
  ## Set cursor to colored pen(cil)
  if currentColor in ['black', '#000000']
    iconCursor board, [
      icon: 'pencil-alt-solid'
      color: currentColor
    ], 0, 1
  else
    iconCursor board, [
      icon: 'pen-solid'
      color: currentColor
    ,
      icon: 'pencil-alt-solid'
      color: 'rgba(0,0,0,0.3)'
    ], 0, 1
  #iconCursor board, [
  #  icon: 'pen-solid'
  #  color: currentColor
  #,
  #  icon: 'pencil-alt-solid'
  #  color: 'black'
  #], 0, 1

Meteor.startup ->
  board = document.getElementById 'board'
  boardBB = board.getBoundingClientRect()
  paletteColors()
  selectColor()
  pointerEvents()
  window.addEventListener 'popstate', pageChange
  pageChange()
