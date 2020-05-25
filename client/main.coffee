import * as icons from './lib/icons.coffee'
import * as dom from './lib/dom.coffee'

board = null     # set to svg#board element
boardBB = null   # client bounding box (top/left/bottom/right) of board
boardRoot = null # root <g> element within board for transform
boardTransform = # board translation/rotation
  x: 0
  y: 0
historyBoard = historyRoot = historyTransform = null
undoStack = []
redoStack = []

pointers = {}   # maps pointerId to tool-specific data
tools =
  undo:
    icon: 'undo'
    title: 'Undo the last operation you did [CTRL-Z]'
    once: ->
      undo()
  redo:
    icon: 'redo'
    title: 'Redo the last operation you undid (if no operations since) [CTRL-Y]'
    once: ->
      redo()
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
    icon: 'pencil-alt'
    hotspot: [0, 1]
    title: 'Freehand drawing'
    down: (e) ->
      return if pointers[e.pointerId]
      pointers[e.pointerId] = Meteor.apply 'objectNew', [
        room: currentRoom
        type: 'pen'
        pts: [eventToPoint e]
        color: currentColor
      ], returnStubValue: true
    up: (e) ->
      return unless pointers[e.pointerId]
      undoableOp
        type: 'new'
        obj: Objects.findOne pointers[e.pointerId]
      delete pointers[e.pointerId]
    move: (e) ->
      return unless pointers[e.pointerId]
      ## iPhone (iOS 13.4, Safari 13.1) sends zero pressure for touch events.
      #if e.pressure == 0
      #  stop e
      #else
      Meteor.call 'objectPush',
        id: pointers[e.pointerId]
        pts: eventToPoint e
  eraser:
    icon: 'eraser'
    hotspot: [0.35, 1]
    title: 'Erase strokes'
    down: (e) ->
      pointers[e.pointerId] ?= new Highlighter
      h = pointers[e.pointerId]
      unless h.down
        h.down = true
        h.deleted = []
      if h.id?
        h.deleted.push Objects.findOne h.id
        Meteor.call 'objectDel', h.id
        h.clear()
    up: (e) ->
      h = pointers[e.pointerId]
      h?.clear()
      if h?.deleted?.length
        undoableOp
          type: 'multi'
          ops:
            for obj in h.deleted
              type: 'del'
              obj: obj
      delete pointers[e.pointerId]
    move: (e) ->
      pointers[e.pointerId] ?= new Highlighter
      h = pointers[e.pointerId]
      target = h.findGroup e
      if target?
        if h.down
          h.deleted.push Objects.findOne target.dataset.id
          Meteor.call 'objectDel', target.dataset.id
          h.clear()
        else
          h.highlight target
      else
        h.clear()
  history:
    icon: 'history'
    hotspot: [0.5, 0.5]
    title: 'Time travel to the past (via bottom slider)'
    start: ->
      document.body.classList.add 'history'
      historyBoard = document.getElementById 'historyBoard'
      historyTransform =
        x: 0
        y: 0
      historyObjects = {}
      range = document.getElementById 'historyRange'
      range.value = 0
      range.addEventListener 'change', pointers.listen = (e) ->
        historyBoard.innerHTML = ''
        historyBoard.appendChild historyRoot = dom.create 'g'
        historyRoot.setAttribute 'transform',
          "translate(#{historyTransform.x} #{historyTransform.y})"
        historyRender = new Render historyRoot
        max = range.max
        value = range.value
        count = 0
        for diff from ObjectsDiff.find room: currentRoom
          count++
          break if count > value
          switch diff.type
            when 'pen'
              obj = diff
              historyObjects[obj.id] = obj
              historyRender.renderPen obj
            when 'push'
              obj = historyObjects[diff.id]
              obj.pts.push diff.pts
              historyRender.renderPen obj, obj.pts.length - 1
            when 'del'
              historyRender.delete diff
              delete historyObjects[diff.id]
          #break if max != range.max or value != range.value
      pointers.sub = Meteor.subscribe 'history', currentRoom
      pointers.auto = Tracker.autorun ->
        range.max = ObjectsDiff.find(room: currentRoom).count()
        pointers.listen()
    stop: ->
      document.body.classList.remove 'history'
      document.getElementById('historyRange').removeEventListener 'change', pointers.listen
      document.getElementById('historyBoard').innerHTML = ''
      pointers.sub.stop()
      pointers.auto.stop()
    down: (e) ->
      pointers[e.pointerId] = eventToPoint e
    up: (e) ->
      delete pointers[e.pointerId]
      if pointers.x? and pointers.y?
        historyTransform.x = pointers.x
        historyTransform.y = pointers.y
    move: (e) ->
      return unless start = pointers[e.pointerId]
      current = eventToPoint e
      pointers.x = historyTransform.x + current.x - start.x
      pointers.y = historyTransform.y + current.y - start.y
      historyRoot.setAttribute 'transform',
        "translate(#{pointers.x} #{pointers.y})"
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
  dom.listen [board, historyBoard],
    pointerdown: (e) ->
      e.preventDefault()
      tools[currentTool].down? e
    pointerenter: (e) ->
      e.preventDefault()
      tools[currentTool].down? e if e.buttons
    pointerup: stop = (e) ->
      e.preventDefault()
      tools[currentTool].up? e
    pointerleave: stop
    pointermove: (e) ->
      e.preventDefault()
      tools[currentTool].move? e

class Highlighter
  findGroup: (target) ->
    target = target.target if target.target?  # given event
    while target.tagName.toLowerCase() in ['circle', 'line']
      target = target.parentNode
    return unless target.tagName.toLowerCase() == 'g'
    return unless target.dataset.id?
    target
  highlight: (target) ->
    return if target == @highlighted
    return unless target.dataset.id?
    @id = target.dataset.id
    @highlighted ?= dom.create 'g', class: 'highlight'
    boardRoot.appendChild @highlighted  # ensure on top
    doubler = (match, left, number, right) -> "#{left}#{2 * number}#{right}"
    @highlighted.innerHTML = target.innerHTML
    .replace /(\bstroke-width=["'])([\d.]+)(["'])/g, doubler
    .replace /(\br=["'])([\d.]+)(["'])/g, doubler
  clear: ->
    if @highlighted?
      boardRoot.removeChild @highlighted
      @highlighted = @id = null

undoableOp = (op) ->
  redoStack = []
  undoStack.push op
doOp = (op, reverse) ->
  switch op.type
    when 'multi'
      ops = op.ops
      ops = ops[..].reverse() if reverse
      for sub in ops
        doOp sub, reverse
    when 'new', 'del'
      if (op.type == 'new') == reverse
        Meteor.call 'objectDel', op.obj._id
      else
        #obj = {}
        #for key, value of op.obj
        #  obj[key] = value unless key of skipKeys
        #op.obj._id = Meteor.apply 'objectNew', [obj], returnStubValue: true
        Meteor.call 'objectNew', op.obj
    else
      console.error "Unknown op type #{op.type} for undo/redo"
undo = ->
  return unless undoStack.length
  op = undoStack.pop()
  doOp op, true
  redoStack.push op
redo = ->
  return unless redoStack.length
  op = redoStack.pop()
  doOp op, false
  undoStack.push op

dot = (obj, p) ->
  dom.create 'circle',
    cx: p.x
    cy: p.y
    r: p.w / 2
    fill: obj.color
edge = (obj, p1, p2) ->
  dom.create 'line',
    x1: p1.x
    y1: p1.y
    x2: p2.x
    y2: p2.y
    stroke: obj.color
    'stroke-width': (p1.w + p2.w) / 2
    # Lines mode:
    #'stroke-width': 1

class Render
  constructor: (@root) ->
    @dom = {}
  id: (obj) ->
    ###
    `obj` can be an `ObjectDiff` object, in which case `id` is the object ID
    (and `_id` is the diff ID); or a regular `Object` object, in which case
    `_id` is the object ID.  Also allow raw ID string for `delete`.
    ###
    obj.id ? obj._id ? obj
  renderPen: (obj, start = 0) ->
    id = @id obj
    unless (g = @dom[id])?
      @dom[id] = g = dom.create 'g', null, dataset: id: id
      @root.appendChild @dom[id]
    for i in [start...obj.pts.length]
      pt = obj.pts[i]
      g.appendChild edge obj, obj.pts[i-1], pt if i > 0
      g.appendChild dot obj, pt
    g
  delete: (obj) ->
    id = @id obj
    unless @dom[id]?
      return console.warn "Attempt to delete unknown object ID #{id}?!"
    @root.removeChild @dom[id]
    delete @dom[id]
  #has: (obj) ->
  #  (id obj) of @dom
  shouldNotExist: (obj) ->
    ###
    Call before rendering a should-be-new object.  If already exists, log a
    warning and clear the object from the map so a new one will get created.
    Currently the old object stays in the DOM, though.
    ###
    id = @id obj
    if id of @dom
      console.warn "Duplicate object with ID #{id}?!"
      delete @dom[id]

observeRender = (room) ->
  render = new Render boardRoot
  Objects.find room: room
  .observe
    # Currently assuming all objects are of type 'pen'
    added: (obj) ->
      render.shouldNotExist obj
      render.renderPen obj
    changed: (obj, old) ->
      # Assumes that pen changes only append to `pts` field
      render.renderPen obj, old.pts.length
    removed: (obj) ->
      render.delete obj

currentRoom = null
roomSub = null
roomObserve = null
changeRoom = (room) ->
  return if room == currentRoom
  roomObserve?.stop()
  roomSub?.stop()
  tool = currentTool
  selectTool null
  rendered = {}
  boardRoot.innerHTML = ''
  currentRoom = room
  if room?
    roomObserve = observeRender room
    roomSub = Meteor.subscribe 'room', room
  selectTool tool

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

lastTool = null
selectTool = (tool) ->
  if tools[tool]?.once?
    return tools[tool].once?()
  tools[currentTool]?.stop?()
  if tool == currentTool == 'history'  # treat history as a toggle
    tool = lastTool
  lastTool = currentTool
  currentTool = tool if tool?  # tool is null if initializing
  dom.select '.tool', "[data-tool='#{currentTool}']"
  if currentTool == 'pen'
    selectColor()
  else if currentTool == 'history'
    icons.iconCursor document.getElementById('historyRange'),
      tools['history'].icon, ...tools['history'].hotspot
    icons.iconCursor document.getElementById('historyBoard'),
      tools['pan'].icon, ...tools['pan'].hotspot
  else
    dom.select '.color'  # deselect color
    icons.iconCursor board, tools[currentTool].icon,
      ...tools[currentTool].hotspot
  pointers = {}  # tool-specific data
  tools[currentTool]?.start?()

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
  icons.iconCursor board, (icons.modIcon 'pencil-alt',
    fill: currentColor
    stroke: 'black'
    'stroke-width': '15'
    'stroke-linecap': 'round'
    'stroke-linejoin': 'round'
  ), ...tools[currentTool].hotspot

resize = ->
  paletteSize = parseFloat (getComputedStyle document.documentElement
  .getPropertyValue '--palette-size')
  toolsDiv = document.getElementById 'tools'
  document.documentElement.style.setProperty '--palette-offset-width',
    "#{toolsDiv.offsetWidth - toolsDiv.clientWidth + # scrollbar width
       paletteSize}px"
  colorsDiv = document.getElementById 'colors'
  document.documentElement.style.setProperty '--palette-offset-height',
    "#{colorsDiv.offsetHeight - colorsDiv.clientHeight + # scrollbar height
       paletteSize}px"
  boardBB = board.getBoundingClientRect()

Meteor.startup ->
  board = document.getElementById 'board'
  board.appendChild boardRoot = dom.create 'g'
  historyBoard = document.getElementById 'historyBoard'
  paletteTools()
  paletteColors()
  selectTool()
  #selectColor()
  pointerEvents()
  dom.listen window,
    resize: resize
    popstate: pageChange
  , true # call now
  dom.listen window,
    keydown: (e) ->
      switch e.key
        when 'z', 'Z'
          if e.ctrlKey or e.metaKey
            if e.shiftKey
              redo()
            else
              undo()
        when 'y', 'Y'
          if e.ctrlKey or e.metaKey
            redo()
