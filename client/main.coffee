import * as icons from './lib/icons.coffee'
import * as dom from './lib/dom.coffee'

board = null     # set to svg#board element
boardBB = null   # client bounding box (top/left/bottom/right) of board
boardRoot = null # root <g> element within board for transform
boardTransform = # board translation/rotation
  x: 0
  y: 0

pointers = {}   # maps pointerId to tool-specific data
tools =
  pan:
    icon: 'arrows-alt'
    hotspot: [0.5, 0.5]
    title: 'Pan around the page'
    down: (e) ->
      pointers[e.pointerId] = eventToPoint e
    up: (e) ->
      delete pointers[e.pointerId]
      if pointers.x? and pointers.y?
        boardTransform.x = pointers.x
        boardTransform.y = pointers.y
    move: (e) ->
      return unless start = pointers[e.pointerId]
      current = eventToPoint e
      pointers.x = boardTransform.x + current.x - start.x
      pointers.y = boardTransform.y + current.y - start.y
      boardRoot.setAttribute 'transform',
        "translate(#{pointers.x} #{pointers.y})"
  pen:
    icon: 'pencil-alt-solid'
    hotspot: [0, 1]
    title: 'Freehand drawing'
    down: (e) ->
      pointers[e.pointerId] = Objects.insert
        room: currentRoom
        type: 'pen'
        pts: [eventToPoint e]
        color: currentColor
    up: (e) ->
      delete pointers[e.pointerId]
    move: (e) ->
      return unless pointers[e.pointerId]
      ## iPhone (iOS 13.4, Safari 13.1) sends zero pressure for touch events.
      #if e.pressure == 0
      #  stop e
      #else
      Objects.update pointers[e.pointerId],
        $push: pts: eventToPoint e
currentTool = 'pan'

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

width = 5

pressureWidth = (e) -> (0.5 + e.pressure) * width
#pressureWidth = (e) -> 2 * e.pressure * width
#pressureWidth = (e) ->
#  t = e.pressure ** 3
#  (0.5 + (1.5 - 0.5) * t) * width

eventToPoint = (e) ->
  x: e.clientX - boardBB.left - boardTransform.x
  y: e.clientY - boardBB.top - boardTransform.y
  w:
    ## iPhone (iOS 13.4, Safari 13.1) sends pressure 0 for touch events.
    ## Android Chrome (Samsung Note 8) sends pressure 1 for touch events.
    ## Just ignore pressure on touch and mouse events; could they make sense?
    if e.pointerType == 'pen'
      w = pressureWidth e
    else
      w = width

pointerEvents = ->
  dom.listen board,
    pointerdown: (e) ->
      e.preventDefault()
      tools[currentTool].down e
    pointerenter: (e) ->
      e.preventDefault()
      tools[currentTool].down e if e.buttons
    pointerup: stop = (e) ->
      e.preventDefault()
      tools[currentTool].up e
    pointerleave: stop
    pointermove: (e) ->
      e.preventDefault()
      tools[currentTool].move e

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
      boardRoot.appendChild rendered[obj._id] = dom.create 'g', null,
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
  boardRoot.innerHTML = ''
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

paletteTools = ->
  toolsDiv = document.getElementById 'tools'
  for tool, {icon, title} of tools
    toolsDiv.appendChild dom.create 'div', null,
      className: 'tool'
      title: title
      dataset: tool: tool
      innerHTML: icons.svgIcon icon
    ,
      click: (e) -> selectTool e.currentTarget.dataset.tool

selectTool = (tool) ->
  currentTool = tool if tool?
  dom.select '.tool', "[data-tool='#{currentTool}']"
  if currentTool == 'pen'
    selectColor()
  else
    dom.select '.color'  # deselect color
    icons.iconCursor board, tools[currentTool].icon,
      ...tools[currentTool].hotspot
  pointers = {}  # tool-specific data

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
  selectTool 'pen' unless currentTool == 'pen'
  dom.select '.color', "[data-color='#{currentColor}']"
  ## Set cursor to colored pencil
  icons.iconCursor board, (icons.modIcon 'pencil-alt-solid',
    fill: currentColor
    stroke: 'black'
    'stroke-width': '15'
    'stroke-linecap': 'round'
    'stroke-linejoin': 'round'
  ), ...tools[currentTool].hotspot

resize = ->
  palette = document.getElementById 'palette'
  paletteWidth = parseFloat (getComputedStyle document.documentElement
  .getPropertyValue '--palette-width')
  document.documentElement.style.setProperty '--palette-offset-width',
    "#{palette.offsetWidth - palette.clientWidth + # scrollbar width
       paletteWidth}px"
  boardBB = board.getBoundingClientRect()

Meteor.startup ->
  board = document.getElementById 'board'
  board.appendChild boardRoot = dom.create 'g'
  paletteTools()
  paletteColors()
  selectTool()
  #selectColor()
  pointerEvents()
  dom.listen window,
    resize: resize
    popstate: pageChange
  resize()
  pageChange()
