import * as icons from './lib/icons.coffee'
import * as dom from './lib/dom.coffee'

colors = [
  'black'   # Windows Journal black
  '#666666' # Windows Journal grey
  '#989898' # medium grey
  '#bbbbbb' # lighter grey
  'white'
  '#333399' # Windows Journal dark blue
  '#3366ff' # Windows Journal light blue
  '#00c7c7' # custom light cyan
  '#008000' # Windows Journal green
  '#00c000' # lighter green
  '#800080' # Windows Journal purple
  '#d000d0' # lighter magenta
  '#a00000' # darker red
  '#ff0000' # Windows Journal red
  '#855723' # custom brown
  #'#ff9900' # Windows Journal orange
  '#ed8e00' # custom orange
  '#eced00' # custom yellow
]
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
    rendered[obj._id].appendChild dom.create 'circle',
      cx: p.x
      cy: p.y
      r: p.w / 2
      fill: obj.color
  edge = (obj, p1, p2) ->
    rendered[obj._id].appendChild dom.create 'line',
      x1: p1.x
      y1: p1.y
      x2: p2.x
      y2: p2.y
      stroke: obj.color
      'stroke-width': (p1.w + p2.w) / 2
      # Lines mode:
      #'stroke-width': 1
  Objects.find room: room
  .observe
    # Currently assuming all objects are of type 'pen'
    added: (obj) ->
      board.appendChild rendered[obj._id] = dom.create 'g', null,
        dataset: id: obj._id
      for pt, i in obj.pts
        edge obj, obj.pts[i-1], pt if i > 0
        dot obj, pt
    changed: (obj, old) ->
      # Assumes that pen changes only append to `pts` field
      for i in [old.pts.length...obj.pts.length]
        pt = obj.pts[i]
        edge obj, obj.pts[i-1], pt if i > 0
        dot obj, pt
    removed: (obj) ->
      return unless rendered[obj._id]?
      board.removeChild rendered[obj._id]
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
  for color in colors
    colorsDiv.appendChild colorDiv = dom.create 'div', null,
      className: 'color'
      style: backgroundColor: color
      dataset: color: color
    ,
      click: (e) -> selectColor e.currentTarget.dataset.color

selectColor = (color) ->
  currentColor = color if color?
  dom.select '.color', "[data-color='#{currentColor}']"
  ## Set cursor to colored pencil
  icons.iconCursor board, (icons.modIcon 'pencil-alt-solid',
    fill: currentColor
    stroke: 'black'
    'stroke-width': '15'
    'stroke-linecap': 'round'
    'stroke-linejoin': 'round'
  ), 0, 1

Meteor.startup ->
  board = document.getElementById 'board'
  boardBB = board.getBoundingClientRect()
  paletteColors()
  selectColor()
  pointerEvents()
  window.addEventListener 'popstate', pageChange
  pageChange()
