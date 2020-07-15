import * as icons from './lib/icons.coffee'
import * as dom from './lib/dom.coffee'
import * as remotes from './lib/remotes.coffee'
import * as throttle from './lib/throttle.coffee'
import * as timesync from './lib/timesync.coffee'

board = null     # set to svg#board element
boardBB = null   # client bounding box (top/left/bottom/right) of board
boardRoot = null # root <g> element within board for transform
boardGrid = null # first <g> element within root for grid background
boardTransform = # board translation/rotation
  x: 0
  y: 0
historyBoard = historyRoot = historyTransform = null
selection = null # Selection object representing selected objects
undoStack = []
redoStack = []
eraseDist = 2   # require movement by this many pixels before erasing swipe
dragDist = 2    # require movement by this many pixels before select drags
remoteIconSize = 24
remoteIconOutside = 0.2  # fraction to render icons outside view
currentRoom = undefined
currentGrid = null
allowTouch = true

distanceThreshold = (p, q, t) ->
  return false if not p or not q
  return true if p == true or q == true
  dx = p.clientX - q.clientX
  dy = p.clientY - q.clientY
  dx * dx + dy * dy >= t * t

pointers = {}   # maps pointerId to tool-specific data
tools =
  undo:
    icon: 'undo'
    help: 'Undo the last operation you did'
    hotkey: 'CTRL-Z'
    once: ->
      undo()
  redo:
    icon: 'redo'
    help: 'Redo: Undo the last undo you did (if you did no operations since)'
    hotkey: 'CTRL-Y'
    once: ->
      redo()
  pan:
    icon: 'arrows-alt'
    hotspot: [0.5, 0.5]
    help: 'Pan around the page by dragging'
    down: (e) ->
      pointers[e.pointerId] = eventToRawPoint e
      pointers[e.pointerId].transform = Object.assign {}, boardTransform
    up: (e) ->
      delete pointers[e.pointerId]
    move: (e) ->
      return unless start = pointers[e.pointerId]
      current = eventToRawPoint e
      boardTransform.x = start.transform.x + current.x - start.x
      boardTransform.y = start.transform.y + current.y - start.y
      boardRoot.setAttribute 'transform',
        "translate(#{boardTransform.x} #{boardTransform.y})"
      remotesRender?.transform()
      ## Do updates after boardRoot's `transform` attribute gets set.
      Meteor.setTimeout ->
        boardGrid.update()
      , 0
  select:
    icon: 'mouse-pointer'
    hotspot: [0.21875, 0.03515625]
    help: 'Select objects (multiple if holding <kbd>SHIFT</kbd>) and then change their color/width or drag to move them'
    hotkey: 's'
    start: ->
      pointers.objects = {}
    stop: selectHighlightReset = ->
      selection.clear()
      for key, highlighter of pointers
        if highlighter instanceof Highlighter
          highlighter.clear()
    down: (e) ->
      pointers[e.pointerId] ?= new Highlighter
      h = pointers[e.pointerId]
      return if h.down  # in case of repeat events
      h.down = e
      h.start = eventToRawPoint e
      h.moved = null
      ## Refresh previously selected objects, in particular so tx/ty up-to-date
      for id in selection.ids()
        pointers.objects[id] = Objects.findOne id
      unless h.id?  # see if we pressed on something
        target = h.findGroup e
        if target?
          h.highlight target
      toggle = e.shiftKey or e.ctrlKey or e.metaKey
      unless toggle or selection.has h.id
        ## Deselect existing selection unless requesting multiselect
        selection.clear()
        pointers.objects = {}
      if h.id?  # have something highlighted, possibly just now
        unless selection.has h.id
          pointers.objects[h.id] = Objects.findOne h.id
          selection.add h
        else
          if toggle
            selection.remove h.id
            delete pointers.objects[h.id]
          h.clear()
    up: (e) ->
      h = pointers[e.pointerId]
      if h?.moved
        undoableOp
          type: 'multi'
          ops:
            for id, obj of pointers.objects
              type: 'edit'
              id: id
              before:
                tx: obj.tx ? 0
                ty: obj.ty ? 0
              after: h.moved[id]
      h?.clear()
      delete pointers[e.pointerId]
    move: (e) ->
      pointers[e.pointerId] ?= new Highlighter
      h = pointers[e.pointerId]
      if h.down
        if distanceThreshold h.down, e, dragDist
          h.down = true
          here = eventToRawPoint e
          ## Don't set h.moved out here in case no objects selected
          for id, obj of pointers.objects
            h.moved ?= {}
            tx = (obj.tx ? 0) + here.x - h.start.x
            ty = (obj.ty ? 0) + here.y - h.start.y
            Meteor.call 'objectEdit', {id, tx, ty}
            h.moved[id] = {tx, ty}
      else
        target = h.findGroup e
        if target?
          h.highlight target
        else
          h.clear()
  pen:
    icon: 'pencil-alt'
    hotspot: [0, 1]
    help: 'Freehand drawing (with pen pressure adjusting width)'
    hotkey: 'p'
    down: (e) ->
      return if pointers[e.pointerId]
      pointers[e.pointerId] = Meteor.apply 'objectNew', [
        room: currentRoom
        type: 'pen'
        pts: [eventToPointW e]
        color: currentColor
        width: currentWidth
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
        pts:
          for e2 in e.getCoalescedEvents?() ? [e]
            eventToPointW e2
  segment:
    icon: 'segment'
    hotspot: [0.0625, 0.9375]
    help: 'Draw straight line segment between endpoints (drag)'
    hotkey: ['l', '\\']
    start: ->
      pointers.throttle = throttle.method 'objectEdit'
    down: (e) ->
      return if pointers[e.pointerId]
      pt = eventToPoint e
      pointers[e.pointerId] = Meteor.apply 'objectNew', [
        room: currentRoom
        type: 'poly'
        pts: [pt, pt]
        color: currentColor
        width: currentWidth
      ], returnStubValue: true
    up: (e) ->
      return unless pointers[e.pointerId]
      undoableOp
        type: 'new'
        obj: Objects.findOne pointers[e.pointerId]
      delete pointers[e.pointerId]
    move: (e) ->
      return unless pointers[e.pointerId]
      pt = eventToPoint e
      ## Force horizontal/vertical line when holding shift
      if e.shiftKey
        start = Objects.findOne(pointers[e.pointerId]).pts[0]
        dx = Math.abs pt.x - start.x
        dy = Math.abs pt.y - start.y
        if dx > dy
          pt.y = start.y
        else
          pt.x = start.x
      pointers.throttle
        id: pointers[e.pointerId]
        pts: 1: pt
  rect:
    icon: 'rect'
    hotspot: [0.0625, 0.883]
    help: 'Draw axis-aligned rectangle between endpoints (drag)'
    hotkey: 'r'
    start: ->
      pointers.throttle = throttle.method 'objectEdit'
    down: (e) ->
      return if pointers[e.pointerId]
      pt = eventToPoint e
      pointers[e.pointerId] = Meteor.apply 'objectNew', [
        room: currentRoom
        type: 'rect'
        pts: [pt, pt]
        color: currentColor
        width: currentWidth
      ], returnStubValue: true
    up: (e) ->
      return unless pointers[e.pointerId]
      undoableOp
        type: 'new'
        obj: Objects.findOne pointers[e.pointerId]
      delete pointers[e.pointerId]
    move: (e) ->
      return unless pointers[e.pointerId]
      pointers.throttle
        id: pointers[e.pointerId]
        pts: 1: eventToPoint e
  ellipse:
    icon: 'ellipse'
    hotspot: [0.201888, 0.75728]
    help: 'Draw axis-aligned ellipsis inside rectangle between endpoints (drag)'
    hotkey: 'o'
    start: ->
      pointers.throttle = throttle.method 'objectEdit'
    down: (e) ->
      return if pointers[e.pointerId]
      pt = eventToPoint e
      pointers[e.pointerId] = Meteor.apply 'objectNew', [
        room: currentRoom
        type: 'ellipse'
        pts: [pt, pt]
        color: currentColor
        width: currentWidth
      ], returnStubValue: true
    up: (e) ->
      return unless pointers[e.pointerId]
      undoableOp
        type: 'new'
        obj: Objects.findOne pointers[e.pointerId]
      delete pointers[e.pointerId]
    move: (e) ->
      return unless pointers[e.pointerId]
      pointers.throttle
        id: pointers[e.pointerId]
        pts: 1: eventToPoint e
  eraser:
    icon: 'eraser'
    hotspot: [0.4, 0.9]
    help: 'Erase entire objects: click for one object, drag for multiple objects'
    hotkey: '-'
    stop: -> selectHighlightReset()
    down: (e) ->
      pointers[e.pointerId] ?= new Highlighter
      h = pointers[e.pointerId]
      return if h.down  # repeat events can happen because of erasure
      h.down = e
      h.deleted = []
      if h.id?  # already have something highlighted
        h.deleted.push Objects.findOne h.id
        Meteor.call 'objectDel', h.id
        h.clear()
      else  # see if we pressed on something
        target = h.findGroup e
        if target?
          h.deleted.push Objects.findOne target.dataset.id
          Meteor.call 'objectDel', target.dataset.id
    up: (e) ->
      h = pointers[e.pointerId]
      h?.clear()
      if h?.deleted?.length
        ## The following is similar to Selection.delete:
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
        if distanceThreshold h.down, e, eraseDist
          h.down = true
          h.deleted.push Objects.findOne target.dataset.id
          Meteor.call 'objectDel', target.dataset.id
          h.clear()
        else
          h.highlight target
      else
        h.clear()
  spacer: {}
  touch:
    icon: 'hand-pointer'
    help: 'Allow drawing with touch. Disable when using a pen-enabled device to ignore palm resting on screen; then touch will only work with pan and select tools.'
    init: touchUpdate = ->
      touchTool = document.querySelector '.tool[data-tool="touch"]'
      if allowTouch
        touchTool.classList.add 'active'
      else
        touchTool.classList.remove 'active'
    once: ->
      allowTouch = not allowTouch
      touchUpdate()
  grid:
    icon: 'grid'
    help: 'Toggle grid/graph paper'
    once: ->
      Meteor.call 'roomGridToggle', currentRoom
  linkRoom:
    icon: 'clipboard-link'
    help: 'Copy a link to this room/board to clipboard (for sharing with others)'
    once: ->
      navigator.clipboard.writeText document.URL
  newRoom:
    icon: icons.stackIcons [
      'door-open'
      icons.modIcon 'circle',
        fill: 'var(--palette-color)'
        transform: "translate(300 256) scale(0.55) translate(-256 -256)"
      icons.modIcon 'plus-circle',
        transform: "translate(300 256) scale(0.45) translate(-256 -256)"
    ]
    help: 'Create a new room/board (with new URL) in a new browser tab/window'
    once: ->
      window.open '/'
  history:
    icon: 'history'
    hotspot: [0.5, 0.5]
    help: 'Time travel to the past (by dragging the bottom slider)'
    start: ->
      document.body.classList.add 'history'
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
        target = range.value
        count = 0
        for diff from ObjectsDiff.find room: currentRoom
          count++
          break if count > target
          switch diff.type
            when 'pen', 'poly', 'rect', 'ellipse'
              obj = diff
              historyObjects[obj.id] = obj
              historyRender.render obj
            when 'push'
              obj = historyObjects[diff.id]
              obj.pts.push ...diff.pts
              historyRender.render obj,
                start: obj.pts.length - diff.pts.length
                translate: false
            when 'edit'
              obj = historyObjects[diff.id]
              for key, value of diff when key not in ['id', 'type']
                switch key
                  when 'pts'
                    for subkey, subvalue of value
                      obj[key][subkey] = subvalue
                  else
                    obj[key] = value
              historyRender.render obj
            when 'del'
              historyRender.delete diff
              delete historyObjects[diff.id]
          #break if max != range.max or value != range.value
      pointers.sub = subscribe 'history', currentRoom
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
      pointers[e.pointerId] = eventToRawPoint e
      pointers[e.pointerId].transform = Object.assign {}, boardTransform
    up: (e) ->
      delete pointers[e.pointerId]
    move: (e) ->
      return unless start = pointers[e.pointerId]
      current = eventToRawPoint e
      historyTransform.x = start.transform.x + current.x - start.x
      historyTransform.y = start.transform.y + current.y - start.y
      historyRoot.setAttribute 'transform',
        "translate(#{historyTransform.x} #{historyTransform.y})"
  'download-svg':
    icon: 'download-svg'
    help: 'Download/export entire drawing as an SVG file'
    once: ->
      ## Compute bounding box, assuming spanned by <circle> (from pen groups),
      ## <polyline>, <rect>, and <ellipse> elements
      min =
        x: Infinity
        y: Infinity
      max =
        x: -Infinity
        y: -Infinity
      for circle in currentBoard().querySelectorAll 'circle'
        x = parseFloat circle.getAttribute 'cx'
        y = parseFloat circle.getAttribute 'cy'
        r = parseFloat circle.getAttribute 'r'
        min.x = Math.min min.x, x - r
        max.x = Math.max max.x, x + r
        min.y = Math.min min.y, y - r
        max.y = Math.max max.y, y + r
      for poly in currentBoard().querySelectorAll 'polyline'
        stroke = (parseFloat poly.getAttribute('stroke-width') ? 0) / 2
        for point in poly.getAttribute('points').split ' '
          match = point.match /^([\-\d.]+),([\-\d.]+)$/
          x = parseFloat match[1]
          y = parseFloat match[2]
          min.x = Math.min min.x, x - stroke
          max.x = Math.max max.x, x + stroke
          min.y = Math.min min.y, y - stroke
          max.y = Math.max max.y, y + stroke
      for rect in currentBoard().querySelectorAll 'rect'
        x = parseFloat rect.getAttribute 'x'
        y = parseFloat rect.getAttribute 'y'
        width = parseFloat rect.getAttribute 'width'
        height = parseFloat rect.getAttribute 'height'
        stroke = (parseFloat rect.getAttribute('stroke-width') ? 0) / 2
        min.x = Math.min min.x, x - stroke
        max.x = Math.max max.x, x + width + stroke
        min.y = Math.min min.y, y - stroke
        max.y = Math.max max.y, y + height + stroke
      for ellipse in currentBoard().querySelectorAll 'ellipse'
        cx = parseFloat ellipse.getAttribute 'x'
        cy = parseFloat ellipse.getAttribute 'y'
        rx = parseFloat ellipse.getAttribute 'rx'
        ry = parseFloat ellipse.getAttribute 'ry'
        stroke = (parseFloat ellipse.getAttribute('stroke-width') ? 0) / 2
        min.x = Math.min min.x, cx - rx - stroke
        max.x = Math.max max.x, cx + rx + stroke
        min.y = Math.min min.y, cy - ry - stroke
        max.y = Math.max max.y, cy + ry + stroke
      if min.x == Infinity
        min.x = min.y = max.x = max.y = 0
      ## Temporarily make grid space entire drawing
      boardGrid.update currentGrid, {min, max}
      ## Create SVG header
      svg = """
        <?xml version="1.0" encoding="utf-8"?>
        <svg xmlns="#{dom.SVGNS}" viewBox="#{min.x} #{min.y} #{max.x - min.x} #{max.y - min.y}">
        <style>
        .grid { stroke-width: 0.96; stroke: #c4e3f4 }
        </style>
        #{currentBoard().innerHTML.replace /^\s*<g transform[^<>]*>/, '<g>'}
        </svg>
      """
      ## Reset grid
      boardGrid.update()
      ## Download file
      download = document.getElementById 'download'
      download.href = URL.createObjectURL new Blob [svg], type: 'image/svg+xml'
      download.download = "cocreate-#{currentRoom}.svg"
      download.click()
  github:
    icon: 'github'
    help: 'Go to Github repository: source code, bug reports, and feature requests'
    once: ->
      import('/package.json').then (json) ->
        window.open json.homepage
currentTool = 'pan'
drawingTools =
  pen: true
  segment: true
  rect: true
  ellipse: true
lastDrawingTool = 'pen'
hotkeys = {}

currentBoard = ->
  if currentTool == 'history'
    historyBoard
  else
    board

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

widths = [
  1
  2
  3
  4
  5
  6
  7
]
currentWidth = 5

## Maps a PointerEvent with `pressure` attribute to a `w` multiplier to
## multiply with the "natural" width of the pen.
pressureW = (e) -> 0.5 + e.pressure
#pressureW = (e) -> 2 * e.pressure
#pressureW = (e) ->
#  t = e.pressure ** 3
#  0.5 + (1.5 - 0.5) * t

eventToPoint = (e) ->
  {x, y} = dom.svgPoint board, e.clientX, e.clientY, boardRoot
  {x, y}

eventToPointW = (e) ->
  pt = eventToPoint e
  pt.w =
    ## iPhone (iOS 13.4, Safari 13.1) sends pressure 0 for touch events.
    ## Android Chrome (Samsung Note 8) sends pressure 1 for touch events.
    ## Just ignore pressure on touch and mouse events; could they make sense?
    if e.pointerType == 'pen'
      w = pressureW e
    else
      w = 1
  pt

eventToRawPoint = (e) ->
  x: e.clientX
  y: e.clientY

restrictTouch = (e) ->
  not allowTouch and \
  e.pointerType == 'touch' and \
  currentTool of drawingTools

pointerEvents = ->
  dom.listen [board, historyBoard],
    pointerdown: (e) ->
      e.preventDefault()
      return if restrictTouch e
      tools[currentTool].down? e
    pointerenter: (e) ->
      e.preventDefault()
      return if restrictTouch e
      tools[currentTool].down? e if e.buttons
    pointerup: stop = (e) ->
      e.preventDefault()
      return if restrictTouch e
      tools[currentTool].up? e
    pointerleave: stop
    pointermove: (e) ->
      e.preventDefault()
      return if restrictTouch e
      tools[currentTool].move? e
    contextmenu: (e) ->
      ## Prevent right click from bringing up context menu, as it interferes
      ## with e.g. drawing.
      e.preventDefault()
  dom.listen board,
    pointermove: (e) ->
      return unless currentRoom?
      return if restrictTouch e
      remotes.update
        room: currentRoom
        tool: currentTool
        color: currentColor
        cursor: eventToPointW e

class Highlighter
  constructor: ->
    @target = null       # <g/polyline/rect/ellipse> that @highlighted based on
    @highlighted = null  # <g/polyline/rect/ellipse class="highlight">
    @id = null           # highlighted object ID
  findGroup: (e) ->
    ## Pen and touch devices don't always seem to set `e.target` correctly;
    ## use `document.elementFromPoint` instead.
    #target = e.target
    #if target.tagName.toLowerCase() == 'svg'
    target = document.elementFromPoint e.clientX, e.clientY
    while target? and (tag = target.tagName.toLowerCase()) in ['circle', 'line']
      target = target.parentNode
    return unless target?
    return unless tag in ['g', 'polyline', 'rect', 'ellipse']
    return unless target.dataset.id?
    #return if target == @highlighted
    ## Shouldn't get pointer events on highlighted or selected overlays thanks
    ## to `pointer-events: none`, but check for them just in case:
    for elt in [target, target.parentNode]
      return if elt?.getAttribute('class') in ['highlight', 'selected']
    target
  highlight: (target) ->
    ## `target` should be the result of `findGroup`,
    ## so satisfies all above conditions.
    @clear()
    @target = target
    @id = target.dataset.id
    @highlighted ?= dom.create 'g', class: 'highlight'
    boardRoot.appendChild @highlighted  # ensure on top
    doubler = (match, left, number, right) -> "#{left}#{2 * number}#{right}"
    @highlighted.innerHTML = target.outerHTML
    #.replace /\bdata-id=["'][^'"]*["']/g, ''
    .replace /(\bstroke-width=["'])([\d.]+)(["'])/g, doubler
    .replace /(\br=["'])([\d.]+)(["'])/g, doubler
    true
  select: (target) ->
    if target?
      @highlight target
    selected = @highlighted
    selected?.setAttribute 'class', 'selected'
    @target = @highlighted = @id = null
    selected
  clear: ->
    if @highlighted?
      boardRoot.removeChild @highlighted
      @target = @highlighted = @id = null

class Selection
  constructor: ->
    @selected = {}  # mapping from object ID to .selected DOM element
    @target = {}    # mapping from object ID to original DOM element
    @rehighlighter = new Highlighter  # used in redraw()
  add: (highlighter) ->
    id = highlighter.id
    return unless id?
    @target[id] = highlighter.target
    @selected[id] = highlighter.select()
  redraw: (id) ->
    boardRoot.removeChild @selected[id]
    @rehighlighter.highlight @target[id]
    @selected[id] = @rehighlighter.select()
  remove: (id) ->
    boardRoot.removeChild @selected[id]
    delete @selected[id]
    delete @target[id]
  clear: ->
    @remove id for id of @selected
  ids: ->
    id for id of @selected
  has: (id) ->
    id of @selected
  count: ->
    @ids().length
  nonempty: ->
    for id of @selected
      return true
    false
  delete: ->
    return unless @nonempty()
    ## The following is similar to eraser.up:
    undoableOp
      type: 'multi'
      ops:
        for id in @ids()
          obj = Objects.findOne id
          Meteor.call 'objectDel', id
          type: 'del'
          obj: obj
    @clear()
  edit: (attrib, value) ->
    undoableOp
      type: 'multi'
      ops:
        for id in @ids()
          obj = Objects.findOne id
          unless obj?[attrib]
            throw new Error "Object #{id} has no #{attrib} attribute"
          type: 'edit'
          id: id
          before: "#{attrib}": obj[attrib]
          after: "#{attrib}": value
    , true

selection = new Selection

undoableOp = (op, now) ->
  redoStack = []
  undoStack.push op
  doOp op if now
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
    when 'edit'
      Meteor.call 'objectEdit', Object.assign
        id: op.id
      ,
        if reverse
          op.before
        else
          op.after
    else
      console.error "Unknown op type #{op.type} for undo/redo"
undo = ->
  if currentTool == 'history'
    return historyAdvance -1
  return unless undoStack.length
  op = undoStack.pop()
  doOp op, true
  redoStack.push op
  selectHighlightReset()
redo = ->
  if currentTool == 'history'
    return historyAdvance +1
  return unless redoStack.length
  op = redoStack.pop()
  doOp op, false
  undoStack.push op
  selectHighlightReset()
historyAdvance = (delta) ->
  range = document.getElementById 'historyRange'
  value = parseInt range.value
  range.value = value + delta
  event = document.createEvent 'HTMLEvents'
  event.initEvent 'change', false, true
  range.dispatchEvent event

dot = (obj, p) ->
  dom.create 'circle',
    cx: p.x
    cy: p.y
    r: obj.width * p.w / 2
    fill: obj.color
edge = (obj, p1, p2) ->
  dom.create 'line',
    x1: p1.x
    y1: p1.y
    x2: p2.x
    y2: p2.y
    stroke: obj.color
    'stroke-width': obj.width * (p1.w + p2.w) / 2
    #'stroke-linecap': 'round' # alternative to dot
    ## Dots mode:
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
  renderPen: (obj, options) ->
    ## Redraw from scratch if no `start` specified, or if color or width changed
    start = 0
    if options?.start?
      start = options.start unless options.color or options.width
    id = @id obj
    if exists = @dom[id]
      ## Destroy existing drawing if starting over
      exists.innerHTML = '' if start == 0
      frag = document.createDocumentFragment()
    else
      frag = dom.create 'g', null, dataset: id: id
    ## Draw a `dot` at each point, and an `edge` between consecutive dots
    if start == 0
      frag.appendChild dot obj, obj.pts[0]
      start = 1
    for i in [start...obj.pts.length]
      pt = obj.pts[i]
      frag.appendChild edge obj, obj.pts[i-1], pt
      frag.appendChild dot obj, pt  # alternative to linecap: round
    if exists
      exists.appendChild frag
    else
      @root.appendChild @dom[id] = frag
    @dom[id]
  renderPoly: (obj) ->
    id = @id obj
    unless (poly = @dom[id])?
      @root.appendChild @dom[id] = poly =
        dom.create 'polyline', null, dataset: id: id
    dom.attr poly,
      points: ("#{x},#{y}" for {x, y} in obj.pts).join ' '
      stroke: obj.color
      'stroke-width': obj.width
      'stroke-linecap': 'round'
      'stroke-linejoin': 'round'
      fill: 'none'
    poly
  renderRect: (obj) ->
    id = @id obj
    unless (rect = @dom[id])?
      @root.appendChild @dom[id] = rect =
        dom.create 'rect', null, dataset: id: id
    xMin = Math.min obj.pts[0].x, obj.pts[1].x
    xMax = Math.max obj.pts[0].x, obj.pts[1].x
    yMin = Math.min obj.pts[0].y, obj.pts[1].y
    yMax = Math.max obj.pts[0].y, obj.pts[1].y
    dom.attr rect,
      x: xMin
      y: yMin
      width: xMax - xMin
      height: yMax - yMin
      stroke: obj.color
      'stroke-width': obj.width
      'stroke-linejoin': 'round'
      fill: 'none'
    rect
  renderEllipse: (obj) ->
    id = @id obj
    unless (ellipse = @dom[id])?
      @root.appendChild @dom[id] = ellipse =
        dom.create 'ellipse', null, dataset: id: id
    xMin = Math.min obj.pts[0].x, obj.pts[1].x
    xMax = Math.max obj.pts[0].x, obj.pts[1].x
    yMin = Math.min obj.pts[0].y, obj.pts[1].y
    yMax = Math.max obj.pts[0].y, obj.pts[1].y
    dom.attr ellipse,
      cx: (xMin + xMax) / 2
      cy: (yMin + yMax) / 2
      rx: (xMax - xMin) / 2
      ry: (yMax - yMin) / 2
      stroke: obj.color
      'stroke-width': obj.width
      fill: 'none'
    ellipse
  render: (obj, options = {}) ->
    elt =
      switch obj.type
        when 'pen'
          @renderPen obj, options
        when 'poly'
          @renderPoly obj, options
        when 'rect'
          @renderRect obj, options
        when 'ellipse'
          @renderEllipse obj, options
        else
          console.warn "No renderer for object of type #{obj.type}"
    if options.translate != false
      if obj.tx? or obj.ty?
        elt.setAttribute 'transform', "translate(#{obj.tx ? 0} #{obj.ty ? 0})"
      else
        elt.removeAttribute 'transform'
    selection.redraw obj._id if selection.has obj._id
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
    added: (obj) ->
      render.shouldNotExist obj
      render.render obj
    changed: (obj, old) ->
      ## Assuming that pen's `pts` field changes only by appending
      render.render obj,
        start: old.pts.length
        translate: obj.tx != old.tx or obj.ty != old.ty
        color: obj.color != old.color
        width: obj.width != old.width
    removed: (obj) ->
      render.delete obj

class RemotesRender
  constructor: ->
    @elts = {}
    @updated = {}
    @transforms = {}
    @svg = document.getElementById 'remotes'
    @svg.innerHTML = ''
    @svg.appendChild @root = dom.create 'g'
    @resize()
  render: (remote, oldRemote = {}) ->
    id = remote._id
    return if id == remotes.id  # don't show own cursor
    @updated[id] = remote.updated
    ## Omit this in case remoteNow() is inaccurate at startup:
    #return if (timesync.remoteNow() - @updated[id]) / 1000 > remotes.fade
    unless elt = @elts[id]
      @elts[id] = elt = dom.create 'g'
      @root.appendChild elt
    unless remote.tool == oldRemote.tool and remote.color == oldRemote.color
      if icon = tools[remote.tool]?.icon
        if remote.tool == 'pen'
          icon = penIcon remote.color ? colors[0]
        elt.innerHTML = icons.cursorIcon icon, ...tools[remote.tool].hotspot
      else
        elt.innerHTML = ''
        return  # don't set transform or opacity
    elt.style.opacity = 1 -
      (timesync.remoteNow() - @updated[id]) / 1000 / remotes.fade
    hotspot = tools[remote.tool]?.hotspot ? [0,0]
    minX = (hotspot[0] - remoteIconOutside) * remoteIconSize
    minY = (hotspot[1] - remoteIconOutside) * remoteIconSize
    maxX = boardBB.width - (1 - hotspot[0] - remoteIconOutside) * remoteIconSize
    maxY = boardBB.height - (1 - hotspot[1] - remoteIconOutside) * remoteIconSize
    do @transforms[id] = ->
      x = remote.cursor.x + boardTransform.x
      y = remote.cursor.y + boardTransform.y
      unless goodX = (minX <= x <= maxX) and
             goodY = (minY <= y <= maxY)
        x1 = boardBB.width / 2
        y1 = boardBB.height / 2
        x2 = x
        y2 = y
        unless goodX
          if x < minX
            x3 = minX
          else if x > maxX
            x3 = maxX
          ## https://mathworld.wolfram.com/Two-PointForm.html
          y3 = y1 + (y2 - y1) / (x2 - x1) * (x3 - x1)
        unless goodY
          if y < minY
            y4 = minY
          else if y > maxY
            y4 = maxY
          x4 = x1 + (x2 - x1) / (y2 - y1) * (y4 - y1)
        if goodX or minX <= x4 <= maxX
          x = x4
          y = y4
        else if goodY or minY <= y3 <= maxY
          x = x3
          y = y3
        else
          x = x3
          y = y3
          if x < minX
            x = minX
          else if x > maxX
            x = maxX
          if y < minY
            y = minY
          else if y > maxY
            y = maxY
      elt.setAttribute 'transform', """
        translate(#{x} #{y})
        scale(#{remoteIconSize})
        translate(#{-hotspot[0]} #{-hotspot[1]})
        scale(#{1/icons.cursorSize})
      """
  delete: (remote) ->
    id = remote._id ? remote
    if elt = @elts[id]
      @root.removeChild elt
      delete @elts[id]
      delete @transforms[id]
  resize: ->
    @svg.setAttribute 'viewBox', "0 0 #{boardBB.width} #{boardBB.height}"
    @transform()
  transform: ->
    for id, transform of @transforms
      transform()
  timer: (elt, id) ->
    now = timesync.remoteNow()
    for id, elt of @elts
      elt.style.opacity = 1 - (now - @updated[id]) / 1000 / remotes.fade

remotesRender = null
observeRemotes = (room) ->
  remotesRender = new RemotesRender
  Remotes.find room: room
  .observe
    added: (remote) -> remotesRender.render remote
    changed: (remote, oldRemote) -> remotesRender.render remote, oldRemote
    removed: (remote) -> remotesRender.delete remote
setInterval ->
  remotesRender?.timer()
, 1000

class Grid
  constructor: (root) ->
    @svg = root.parentNode
    root.appendChild @grid = dom.create 'g', class: 'grid'
    @update()
  update: (mode = currentGrid, bounds) ->
    gridSize = 37.76
    @grid.innerHTML = ''
    bounds ?=
      min: dom.svgPoint @svg, boardBB.left, boardBB.top, @grid
      max: dom.svgPoint @svg, boardBB.right, boardBB.bottom, @grid
    margin = gridSize
    switch mode
      when true
        far = 10 * gridSize
        range = (xy) ->
          [Math.floor(bounds.min[xy] / gridSize) .. \
           Math.ceil bounds.max[xy] / gridSize]
        for i in range 'x'
          x = i * gridSize
          @grid.appendChild dom.create 'line',
            x1: x
            x2: x
            y1: bounds.min.y - margin
            y2: bounds.max.y + margin
        for j in range 'y'
          y = j * gridSize
          @grid.appendChild dom.create 'line',
            y1: y
            y2: y
            x1: bounds.min.x - margin
            x2: bounds.max.x + margin
      #else

loadingCount = 0
loadingUpdate = (delta) ->
  loadingCount += delta
  loading = document.getElementById 'loading'
  if loadingCount > 0
    loading.classList.add 'loading'
  else
    loading.classList.remove 'loading'
    updateBadRoom()

updateBadRoom = ->
  badRoom = document.getElementById 'badRoom'
  if Rooms.findOne currentRoom
    badRoom.classList.remove 'show'
  else
    badRoom.classList.add 'show'
    currentRoom = null

subscribe = (...args) ->
  delta = 1
  loadingUpdate delta
  done = ->
    loadingUpdate -delta
    delta = 0
  Meteor.subscribe ...args,
    onReady: done
    onStop: done

roomSub = null
roomObserveObjects = null
roomObserveRemotes = null
roomAuto = null
changeRoom = (room) ->
  return if room == currentRoom
  roomAuto?.stop()
  roomObserve?.stop()
  roomSub?.stop()
  tool = currentTool
  selectTool null
  rendered = {}
  boardRoot.innerHTML = ''
  boardGrid = new Grid boardRoot
  currentRoom = room
  if room?
    roomObserveObjects = observeRender room
    roomObserveRemotes = observeRemotes room
    roomSub = subscribe 'room', room
  else
    updateBadRoom()
  selectTool tool
  roomAuto = Tracker.autorun ->
    roomData = Rooms.findOne currentRoom
    gridTool = document.querySelector '.tool[data-tool="grid"]'
    if currentGrid != roomData?.grid
      currentGrid = roomData?.grid
      if currentGrid
        gridTool.classList.add 'active'
      else
        gridTool.classList.remove 'active'
      boardGrid.update()

pageChange = ->
  if document.location.pathname == '/'
    Meteor.call 'roomNew',
      grid: true
    , (error, room) ->
      if error?
        return console.error "Failed to create new room on server: #{error}"
      history.replaceState null, 'new room', "/r/#{room}"
      pageChange()
  else if match = document.location.pathname.match /^\/r\/(\w*)$/
    changeRoom match[1]
  else
    changeRoom null

paletteTools = ->
  tooltip = null  # currently open tooltip
  toolsDiv = document.getElementById 'tools'
  align = 'top'
  for tool, {icon, help, hotkey, init} of tools
    if tool.startsWith 'spacer'
      toolsDiv.appendChild dom.create 'div', class: 'spacer'
      align = 'bottom'
    else
      toolsDiv.appendChild div = dom.create 'div', null,
        className: 'tool'
        dataset: tool: tool
        innerHTML: icons.svgIcon icon
      ,
        click: (e) -> selectTool e.currentTarget.dataset.tool
      if help
        if hotkey
          hotkey = [hotkey] unless Array.isArray hotkey
          for key in hotkey
            help += """<kbd class="hotkey">#{key}</kbd>"""
            hotkeys[key] = tool
        do (div, align, help) ->
          dom.listen div,
            pointerenter: ->
              tooltip.remove() if tooltip?
              document.body.appendChild tooltip = dom.create 'div', null,
                className: "tooltip #{align}"
                innerHTML: help
                style: "#{align}":
                  if align == 'top'
                    "#{div.getBoundingClientRect().top}px"
                  else
                    "calc(100% - #{div.getBoundingClientRect().bottom}px)"
              ,
                pointerenter: ->
                  tooltip.remove() if tooltip?
                  tooltip = null
            pointerleave: ->
              tooltip.remove() if tooltip?
              tooltip = null
      init?()

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
    selectColor() # set color-specific pen icon
  else if currentTool == 'history'
    icons.setCursor document.getElementById('historyRange'),
      tools['history'].icon, ...tools['history'].hotspot
    icons.setCursor document.getElementById('historyBoard'),
      tools['pan'].icon, ...tools['pan'].hotspot
  else
    # Deselect color and width if not in pen mode
    #dom.select '.color'
    #dom.select '.width'
    icons.setCursor board, tools[currentTool].icon,
      ...tools[currentTool].hotspot
  pointers = {}  # tool-specific data
  tools[currentTool]?.start?()
  lastDrawingTool = currentTool if currentTool of drawingTools
selectDrawingTool = ->
  unless currentTool of drawingTools
    selectTool lastDrawingTool

paletteColors = ->
  colorsDiv = document.getElementById 'colors'
  for color in colors
    colorsDiv.appendChild dom.create 'div', null,
      className: 'color'
      style: backgroundColor: color
      dataset: color: color
    ,
      click: (e) -> selectColor e.currentTarget.dataset.color

widthSize = 22
paletteWidths = ->
  widthsDiv = document.getElementById 'colors'
  for width in widths
    widthsDiv.appendChild dom.create 'div', null,
      className: 'width'
      dataset: width: width
    ,
      click: (e) -> selectWidth e.currentTarget.dataset.width
    , [
      dom.create 'svg',
        viewBox: "0 #{-widthSize/3} #{widthSize} #{widthSize}"
        width: widthSize
        height: widthSize
      , null, null
      , [
        dom.create 'line',
          x2: widthSize
          'stroke-width': width
        dom.create 'text',
          x: widthSize/2
          y: widthSize*2/3
        , null, null, [
          document.createTextNode "#{width}"
        ]
      ]
    ]

penIcon = (color) ->
  icons.modIcon 'pencil-alt',
    fill: color
    stroke: 'black'
    'stroke-width': '15'
    'stroke-linecap': 'round'
    'stroke-linejoin': 'round'

selectColor = (color, keepTool) ->
  currentColor = color if color?
  dom.select '.color', "[data-color='#{currentColor}']"
  document.documentElement.style.setProperty '--currentColor', currentColor
  if selection.nonempty()
    selection.edit 'color', currentColor
    keepTool = true
  selectDrawingTool() unless keepTool
  ## Set cursor to colored pencil
  if currentTool == 'pen'
    icons.setCursor board, penIcon(currentColor), ...tools[currentTool].hotspot

selectWidth = (width, keepTool) ->
  currentWidth = parseFloat width if width?
  if selection.nonempty()
    selection.edit 'width', currentWidth
    keepTool = true
  selectDrawingTool() unless keepTool
  dom.select '.width', "[data-width='#{currentWidth}']"

paletteSize = ->
  parseFloat (getComputedStyle document.documentElement
  .getPropertyValue '--palette-size')

resize = ->
  toolsDiv = document.getElementById 'tools'
  document.documentElement.style.setProperty '--palette-offset-width',
    "#{toolsDiv.offsetWidth - toolsDiv.clientWidth + # scrollbar width
       paletteSize()}px"
  colorsDiv = document.getElementById 'colors'
  document.documentElement.style.setProperty '--palette-offset-height',
    "#{colorsDiv.offsetHeight - colorsDiv.clientHeight + # scrollbar height
       paletteSize()}px"
  boardBB = board.getBoundingClientRect()
  boardGrid?.update()
  remotesRender?.resize()

Meteor.startup ->
  document.getElementById('loading').innerHTML = icons.svgIcon 'spinner'
  board = document.getElementById 'board'
  board.appendChild boardRoot = dom.create 'g'
  historyBoard = document.getElementById 'historyBoard'
  paletteTools()
  paletteWidths()
  paletteColors()
  selectTool()
  selectColor null, true
  selectWidth null, true
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
        when 'Delete', 'Backspace'
          selection.delete()
        else
          tool = hotkeys[e.key.toLowerCase()]
          selectTool tool if tool?
  document.getElementById('roomLinkStyle').innerHTML =
    Meteor.absoluteUrl 'r/ABCD23456789vwxyz'
  document.getElementById('newRoomLink').setAttribute 'href',
    Meteor.absoluteUrl()

## Cocreate doesn't perform great in combination with Meteor DevTools;
## prevent it from applying its hooks.
window.__devtools = true
