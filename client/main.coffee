import '../lib/main'
import './lib/polyfill'
import icons from './lib/icons'
import dom from './lib/dom'
import remotes from './lib/remotes'
import storage from './lib/storage'
import throttle from './lib/throttle'
import {meteorCallPromise} from '/lib/meteorPromise'
import {Board} from './Board'
import {Grid, gridSize} from './Grid'
import {RenderObjects} from './RenderObjects'
import {RenderRemotes} from './RenderRemotes'
import {Selection, Highlighter, highlighterClear} from './Selection'
import {UndoStack} from './UndoStack'

board = historyBoard = null # Board objects
gridDefault = true
eraseDist = 2   # require movement by this many pixels before erasing swipe
dragDist = 2    # require movement by this many pixels before select drags
export selection = null # Selection object representing selected objects
export undoStack = new UndoStack
export room = null
currentFill = 'white'
currentFillOn = false
name = new storage.StringVariable 'name', '', updateName = ->
  nameInput = document.getElementById 'name'
  nameInput.value = name.get() unless nameInput.value == name.get()
updateName()
allowTouch = new storage.Variable 'allowTouch', true, -> updateAllowTouch()
fancyCursor = new storage.Variable 'fancyCursor',
  #true,
  ## Chromium 86 has a bug with SVG cursors causing an annoying offset.
  ## See https://bugs.chromium.org/p/chromium/issues/detail?id=1138488
  not /Chrom(e|ium)\/86\./.test(navigator.userAgent),
  updateFancyCursor
dark = new storage.Variable 'dark', false, -> updateDark()
spaceDown = false
firefox = /Firefox\//.test navigator.userAgent

if navigator?.platform?.startsWith? 'Mac'
  Ctrl = 'Command'
  Alt = 'Option'
else
  Ctrl = 'Ctrl'
  Alt = 'Alt'

distanceThreshold = (p, q, t) ->
  return false if not p or not q
  return true if p == true or q == true
  dx = p.clientX - q.clientX
  dy = p.clientY - q.clientY
  dx * dx + dy * dy >= t * t

export pointers = {}   # maps pointerId to tool-specific data
export tools =
  undo:
    icon: 'undo'
    help: 'Undo the last operation you did'
    hotkey: "#{Ctrl}-Z"
    once: ->
      if currentTool == 'history'
        historyAdvance -1
      else
        setSelection undoStack.undo()
  redo:
    icon: 'redo'
    help: 'Redo: Undo the last undo you did (if you did no operations since)'
    hotkey: ["#{Ctrl}-Y", "#{Ctrl}-Shift-Z"]
    once: ->
      if currentTool == 'history'
        historyAdvance +1
      else
        setSelection undoStack.redo()
  pan:
    icon: 'arrows-alt'
    hotspot: [0.5, 0.5]
    help: 'Pan around the page by dragging'
    hotkey: 'hold SPACE'
    down: (e) ->
      pointers[e.pointerId] = eventToRawPoint e
      pointers[e.pointerId].transform = Object.assign {}, board.transform
    up: (e) ->
      delete pointers[e.pointerId]
    move: (e) ->
      return unless start = pointers[e.pointerId]
      current = eventToRawPoint e
      board.transform.x = start.transform.x +
        (current.x - start.x) / board.transform.scale
      board.transform.y = start.transform.y +
        (current.y - start.y) / board.transform.scale
      board.retransform()
  select:
    icon: 'mouse-pointer'
    hotspot: [0.21875, 0.03515625]
    help: "Select objects by dragging rectangle#{if firefox then ' (<i>not currently supported on Firefox</i>)' else ''} or clicking on individual objects (toggling multiple if holding <kbd>Shift</kbd>). Then change their color/width, move by dragging (<kbd>Shift</kbd> for horizontal/vertical), duplicate via <kbd>#{Ctrl}-D</kbd>, or <kbd>Delete</kbd> them."
    hotkey: 's'
    start: ->
      pointers.objects = {}
    stop: selectHighlightReset = (nextTool) ->
      selection.clear() unless nextTool == 'text'
      highlighterClear()
    down: (e) ->
      pointers[e.pointerId] ?= new Highlighter board
      h = pointers[e.pointerId]
      return if h.down  # in case of repeat events
      h.down = e
      h.start = eventToPoint e
      h.moved = null
      h.edit = throttle.func (diffs) ->
        Meteor.call 'objectsEdit', (diff for id, diff of diffs)
      , (older = {}, newer) ->
        Object.assign older, newer
      ## Check for clicking on a selected object, to ensure dragging selection
      ## works even when another object is more topmost.
      if (sel = h.eventSelected e, selection).length
        h.highlight sel[0]
      ## Deselect existing selection unless requesting multiselect
      toggle = e.shiftKey or e.ctrlKey or e.metaKey
      unless toggle or selection.has h.id
        selection.clear()
      ## Refresh previously selected objects, in particular so tx/ty up-to-date
      pointers.objects = {}
      for id in selection.ids()
        pointers.objects[id] = Objects.findOne id
      unless h.id?  # see if we pressed on something
        target = h.eventTop e
        if target?
          h.highlight target
      if h.id?  # have something highlighted, possibly just now
        h.start = snapPoint h.start  # don't snap selection rectangle
        unless selection.has h.id
          pointers.objects[h.id] = Objects.findOne h.id
          selection.add h
          selection.setAttributes() if selection.count() == 1
        else
          if toggle
            selection.remove h.id
            delete pointers.objects[h.id]
          h.clear()
      else  # click on blank space -> show selection rectangle
        board.root.appendChild h.selector = dom.create 'rect',
          class: 'selector'
          x1: h.start.x
          y1: h.start.y
    up: (e) ->
      h = pointers[e.pointerId]
      if h?.selector?
        start = dom.svgTransformPoint board.svg, h.start, board.root
        here = eventToPoint e
        here = dom.svgTransformPoint board.svg, here, board.root
        rect = dom.pointsToSVGRect start, here, board.svg, board.root
        matched = []
        for elt in board.root.childNodes
          continue if elt.classList.contains 'grid'
          continue if elt.classList.contains 'selected'
          continue if elt.classList.contains 'highlight'
          continue unless elt.dataset.id
          ## Check whether any descendant non-<g> element intersects.
          ## (SVG.checkIntersection doesn't work for <g> elements.)
          recurse = (part) ->
            if part.tagName == 'g'
              for subpart in part.childNodes
                return true if recurse subpart
            else if board.svg.checkIntersection? part, rect
              return true
            false
          if recurse elt  # hit
            matched.push elt
        ## Now that we've traversed the DOM, modify the selection
        for elt in matched
          if selection.has elt.dataset.id  # Toggle selection
            selection.remove elt.dataset.id
          else
            h.highlight elt
            selection.add h
        selection.setAttributes()
        h.selector.remove()
        h.selector = null
      else if h?.moved
        h.edit.flush()
        undoStack.push
          type: 'multi'
          ops:
            for id, obj of pointers.objects when obj?
              type: 'edit'
              id: id
              before:
                tx: obj.tx ? 0
                ty: obj.ty ? 0
              after: h.moved[id]
      h?.clear()
      delete pointers[e.pointerId]
    move: (e) ->
      pointers[e.pointerId] ?= new Highlighter board
      h = pointers[e.pointerId]
      if h.down
        if h.selector?
          here = eventToPoint e
          dom.attr h.selector, dom.pointsToRect h.start, here
        else if distanceThreshold h.down, e, dragDist
          h.down = true
          here = snapPoint eventToOrthogonalPoint e, h.start
          ## Don't set h.moved out here in case no objects selected
          diffs = {}
          for id, obj of pointers.objects when obj?
            h.moved ?= {}
            tx = (obj.tx ? 0) + (here.x - h.start.x)
            ty = (obj.ty ? 0) + (here.y - h.start.y)
            continue if h.moved[id]?.tx == tx and h.moved[id]?.ty == ty
            diffs[id] = {id, tx, ty}
            h.moved[id] = {tx, ty}
          h.edit diffs if (id for id of diffs).length
      else
        target = h.eventTop e
        if target?
          h.highlight target
        else
          h.clear()
    select: (ids) ->
      selection.addId id for id in ids
  pen:
    icon: 'pencil-alt'
    hotspot: [0, 1]
    help: 'Freehand drawing (with pen pressure adjusting width)'
    hotkey: 'p'
    down: (e) ->
      return if pointers[e.pointerId]
      pointers[e.pointerId] =
        id: Meteor.apply 'objectNew', [
          room: room.id
          page: room.page
          type: 'pen'
          pts: [eventToPointW e]
          color: currentColor
          width: currentWidth
        ], returnStubValue: true
        push: throttle.method 'objectPush', ([older], [newer]) ->
          console.assert older.id == newer.id
          older.pts.push ...newer.pts
          [older]
    up: (e) ->
      return unless pointers[e.pointerId]
      pointers[e.pointerId].push.flush()
      undoStack.push
        type: 'new'
        obj: Objects.findOne pointers[e.pointerId].id
      delete pointers[e.pointerId]
    move: (e) ->
      return unless pointers[e.pointerId]
      ## iPhone (iOS 13.4, Safari 13.1) sends zero pressure for touch events.
      #if e.pressure == 0
      #  stop e
      #else
      pointers[e.pointerId].push
        id: pointers[e.pointerId].id
        pts:
          for e2 in e.getCoalescedEvents?() ? [e]
            eventToPointW e2
  segment:
    icon: 'segment'
    hotspot: [0.0625, 0.9375]
    help: "Draw straight line segment between endpoints (drag). Hold <kbd>Shift</kbd> to constrain to horizontal/vertical, <kbd>#{Alt}</kbd> to center at first point."
    hotkey: ['l', '\\']
    down: (e) ->
      return if pointers[e.pointerId]
      origin = snapPoint eventToPoint e
      pointers[e.pointerId] =
        origin: origin
        id: Meteor.apply 'objectNew', [
          room: room.id
          page: room.page
          type: 'poly'
          pts: [origin, origin]
          color: currentColor
          width: currentWidth
        ], returnStubValue: true
        edit: throttle.method 'objectEdit'
    up: (e) ->
      return unless pointers[e.pointerId]
      pointers[e.pointerId].edit.flush()
      undoStack.push
        type: 'new'
        obj: Objects.findOne pointers[e.pointerId].id
      delete pointers[e.pointerId]
    move: (e) ->
      return unless pointers[e.pointerId]
      {origin, id, alt, last, edit} = pointers[e.pointerId]
      pts =
        1: snapPoint eventToOrthogonalPoint e, origin
      ## When holding Alt/Option, make origin be the center.
      if e.altKey
        pts[0] = symmetricPoint pts[1], origin
      else if alt  # was holding down Alt, go back to original first point
        pts[0] = origin
      pointers[e.pointerId].alt = e.altKey
      return if JSON.stringify(last) == JSON.stringify(pts)
      pointers[e.pointerId].last = pts
      edit
        id: id
        pts: pts
  rect:
    icon: 'rect'
    iconFill: 'rect-fill'
    hotspot: [0.0625, 0.883]
    help: "Draw axis-aligned rectangle between endpoints (drag). Hold <kbd>Shift</kbd> to constrain to square, <kbd>#{Alt}</kbd> to center at first point."
    hotkey: 'r'
    down: (e) ->
      return if pointers[e.pointerId]
      origin = snapPoint eventToPoint e
      object =
        room: room.id
        page: room.page
        type: 'rect'
        pts: [origin, origin]
        color: currentColor
        width: currentWidth
      object.fill = currentFill if currentFillOn
      pointers[e.pointerId] =
        origin: origin
        id: Meteor.apply 'objectNew', [object], returnStubValue: true
        edit: throttle.method 'objectEdit'
    up: (e) ->
      return unless pointers[e.pointerId]
      pointers[e.pointerId].edit.flush()
      undoStack.push
        type: 'new'
        obj: Objects.findOne pointers[e.pointerId].id
      delete pointers[e.pointerId]
    move: rectMove = (e) ->
      return unless pointers[e.pointerId]
      {id, origin, alt, last, edit} = pointers[e.pointerId]
      pts =
        1: snapPoint eventToConstrainedPoint e, origin
      ## When holding Alt/Option, make origin be the center.
      if e.altKey
        pts[0] = symmetricPoint pts[1], origin
      else if alt  # was holding down Alt, go back to original first point
        pts[0] = origin
      pointers[e.pointerId].alt = e.altKey
      return if JSON.stringify(last) == JSON.stringify(pts)
      pointers[e.pointerId].last = pts
      edit
        id: id
        pts: pts
  ellipse:
    icon: 'ellipse'
    iconFill: 'ellipse-fill'
    hotspot: [0.201888, 0.75728]
    help: "Draw axis-aligned ellipsis inside rectangle between endpoints (drag). Hold <kbd>Shift</kbd> to constrain to circle, <kbd>#{Alt}</kbd> to center at first point."
    hotkey: 'o'
    down: (e) ->
      return if pointers[e.pointerId]
      origin = snapPoint eventToPoint e
      object =
        room: room.id
        page: room.page
        type: 'ellipse'
        pts: [origin, origin]
        color: currentColor
        width: currentWidth
      object.fill = currentFill if currentFillOn
      pointers[e.pointerId] =
        origin: origin
        id: Meteor.apply 'objectNew', [object], returnStubValue: true
        edit: throttle.method 'objectEdit'
    up: (e) ->
      return unless pointers[e.pointerId]
      pointers[e.pointerId].edit.flush()
      undoStack.push
        type: 'new'
        obj: Objects.findOne pointers[e.pointerId].id
      delete pointers[e.pointerId]
    move: rectMove
  eraser:
    icon: 'eraser'
    hotspot: [0.4, 0.9]
    help: 'Erase entire objects: click for one object, drag for multiple objects'
    hotkey: 'x'
    stop: -> selectHighlightReset()
    down: (e) ->
      pointers[e.pointerId] ?= new Highlighter board
      h = pointers[e.pointerId]
      return if h.down  # repeat events can happen because of erasure
      h.down = e
      h.deleted = []
      if h.id?  # already have something highlighted
        h.deleted.push Objects.findOne h.id
        Meteor.call 'objectDel', h.id
        h.clear()
      else  # see if we pressed on something
        target = h.eventTop e
        if target?
          h.deleted.push Objects.findOne target.dataset.id
          Meteor.call 'objectDel', target.dataset.id
    up: (e) ->
      h = pointers[e.pointerId]
      h?.clear()
      if h?.deleted?.length
        ## The following is similar to Selection.delete:
        undoStack.push
          type: 'multi'
          ops:
            for obj in h.deleted
              type: 'del'
              obj: obj
      delete pointers[e.pointerId]
    move: (e) ->
      pointers[e.pointerId] ?= new Highlighter board
      h = pointers[e.pointerId]
      target = h.eventCoalescedTop e
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
  text:
    icon: 'text'
    hotspot: [.77, .89]
    help: 'Type text (click location or existing text, then type at bottom), including Markdown *italic*, **bold**, ***bold italic***, `code`, ~~strike~~, and LaTeX $math$, $$displaymath$$'
    hotkey: 't'
    init: ->
      input = document.getElementById 'textInput'
      updateTextCursor = (e) ->
        setTimeout ->
          return unless pointers.text?
          room.render.render Objects.findOne(pointers.text), text: true
        , 0
      dom.listen input,
        keydown: (e) ->
          e.stopPropagation() # avoid hotkeys
          e.target.blur() if e.key == 'Escape'
          updateTextCursor e
        click: updateTextCursor
        paste: updateTextCursor
        input: (e) ->
          return unless pointers.text?
          text = input.value
          if text != (oldText = Objects.findOne(pointers.text).text)
            Meteor.call 'objectEdit',
              id: pointers.text
              text: text
            unless pointers.undoable?
              undoStack.push pointers.undoable =
                type: 'multi'
                ops: [
                  type: 'edit'
                  id: pointers.text
                  before: text: oldText
                  after: text: text
                ]
            console.assert pointers.undoable.ops.length == 1
            switch pointers.undoable.ops[0].type
              when 'new'
                pointers.undoable.ops[0].obj.text = text
              when 'edit'
                pointers.undoable.ops[0].after.text = text
    start: ->
      pointers.highlight = new Highlighter board, 'text'
      if (ids = selection.ids()).length == 1 and
         (obj = Objects.findOne(ids[0]))?.type == 'text'
        pointers.text = obj._id
        input = document.getElementById 'textInput'
        input.value = obj.text ? ''
        input.disabled = false
        setTimeout (-> input.focus()), 0  # wait for input to show
      else
        tools.text.stop()
    stop: (nextTool, keepHighlight) ->
      input = document.getElementById 'textInput'
      input.value = ''
      input.disabled = true
      selection.clear() unless nextTool == 'select'
      pointers.highlight?.clear() unless keepHighlight
      pointers.cursor?.remove()
      pointers.cursor = null
      return unless (id = pointers.text)?
      if (object = Objects.findOne id)?
        unless object.text
          undoStack.remove pointers.undoable
          Meteor.call 'objectDel', id
      pointers.undoable = null
      pointers.text = null
    up: (e) ->
      return unless e.type == 'pointerup' # ignore pointerleave
      ## Stop editing any previous text object.
      tools.text.stop null, true
      ## In future, may support dragging a rectangular container for text,
      ## but maybe only after SVG 2's <text> flow support...
      h = pointers.highlight
      unless h.id?
        if (target = h.eventTop e)?
          h.highlight target
      if h.id?
        pointers.text = h.id
        selection.add h
        selection.setAttributes()
        text = Objects.findOne(pointers.text)?.text ? ''
      else
        pointers.text = Meteor.apply 'objectNew', [
          room: room.id
          page: room.page
          type: 'text'
          pts: [snapPoint eventToPoint e]
          text: text = ''
          color: currentColor
          fontSize: currentFontSize
        ], returnStubValue: true
        selection.addId pointers.text
        undoStack.push pointers.undoable =
          type: 'multi'
          ops: [
            type: 'new'
            obj: object = Objects.findOne pointers.text
          ]
      input = document.getElementById 'textInput'
      input.value = text
      input.disabled = false
      input.focus()
    move: (e) ->
      h = pointers.highlight
      target = h.eventTop e
      if target? and Objects.findOne(target.dataset.id).type == 'text'
        h.highlight target
      else
        h.clear()
    select: (ids) ->
      return unless ids.length == 1
      return if pointers.text == ids[0]
      obj = Objects.findOne ids[0]
      return unless obj?.type == 'text'
      tools.text.stop()
      pointers.text = obj._id
      selection.addId pointers.text
      input = document.getElementById 'textInput'
      input.value = obj.text
      input.disabled = false
      ## Giving the input focus makes it hard to do repeated global undo/redo;
      ## instead the text-entry box does its own undo/redo.
      #input.focus()
  spacer: {}
  touch:
    icon: 'hand-pointer'
    help: 'Toggle drawing with touch. Disable when using a pen-enabled device to ignore palm resting on screen; then touch will only work with pan and select tools.'
    init: updateAllowTouch = ->
      dom.classSet document.querySelector('.tool[data-tool="touch"]'),
        'active', allowTouch.get()
    once: ->
      allowTouch.set not allowTouch.get()
      updateAllowTouch()
  crosshair:
    icon: 'plus'
    help: 'Use crosshair mouse cursor instead of tool-specific mouse cursor. Easier to aim precisely, and works around a Chrome bug.'
    init: updateFancyCursor = ->
      dom.classSet document.querySelector('.tool[data-tool="crosshair"]'),
        'active', not fancyCursor.get()
      selectTool()
    once: ->
      fancyCursor.set not fancyCursor.get()
      updateFancyCursor()
  dark:
    icon: 'moon'
    help: 'Toggle dark mode (just for you), which flips dark and light colors.'
    init: updateDark = ->
      dom.classSet document.querySelector('.tool[data-tool="dark"]'),
        'active', dark.get()
      dom.classSet document.body, 'dark', dark.get()
      updateCursor()
    once: ->
      dark.set not dark.get()
      updateDark()
  grid:
    icon: 'grid'
    help: 'Toggle grid/graph paper'
    once: ->
      Meteor.call 'gridToggle', room.page
  gridSnap:
    icon: 'grid-snap'
    help: 'Toggle snapping to grid (except pen tool)'
    hotkey: '#'
    init: updateGridSnap = ->
      dom.classSet document.querySelector('.tool[data-tool="gridSnap"]'),
        'active', room?.gridSnap.get()
    once: ->
      room?.gridSnap.set not room?.gridSnap.get()
      updateGridSnap()
  linkRoom:
    icon: 'clipboard-link'
    help: 'Share a link to this room/board: show the URL, copy it to the clipboard, and show a QR code.'
    once: toggleLinkRoom = ->
      dom.classToggle document.getElementById('qrCode'), 'show'
      dom.classToggle document.querySelector('.tool[data-tool="linkRoom"]'),
        'active'
      if document.getElementById('qrCode').classList.contains 'show'
        try
          navigator.clipboard.writeText document.URL
        close = document.querySelector '#qrCode .close'
        close.innerHTML = icons.svgIcon \
          icons.modIcon 'times-circle', fill: 'currentColor'
        close.removeEventListener 'click', toggleLinkRoom
        close.addEventListener 'click', toggleLinkRoom
        document.getElementById('qrCodeSvg').innerHTML = ''
        do updateRoomLink = ->
          document.getElementById('linkToRoom').href = document.URL
          document.getElementById('linkToRoom').innerText = document.URL
          import('qrcode-svg').then (QRCode) ->
            document.getElementById('qrCodeSvg').innerHTML =
              new QRCode.default
                content: document.URL
                ecl: 'M'
                join: true
                container: 'svg-viewbox'
              .svg()
      else
        updateRoomLink = null
  newRoom:
    icon: 'door-plus-circle'
    help: 'Create a new room/board (with new URL) in a new browser tab/window'
    once: ->
      window.open '/'
  history:
    icon: 'history'
    hotspot: [0.5, 0.5]
    help: 'Time travel to the past (by dragging the bottom slider)'
    start: ->
      historyObjects = {}
      range = document.getElementById 'historyRange'
      range.value = 0
      query =
        room: room.id
        page: room.page
      lastTarget = null
      historyRender = null
      diffs = []
      range.addEventListener 'change', pointers.listen = (e) ->
        target = parseInt range.value
        ## Re-use last object set and render if just increasing in time.
        if lastTarget? and target >= lastTarget
          apply = diffs[lastTarget...target]
        else
          historyBoard.clear()
          historyBoard.retransform()
          historyRender = new RenderObjects historyBoard.root
          apply = diffs[...target]
        return if apply.length == 0
        lastTarget = target
        for diff in apply
          switch diff.type
            when 'pen', 'poly', 'rect', 'ellipse', 'text'
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
      range.max = 0
      loadingUpdate +1
      diffs = await meteorCallPromise 'history', room.id, room.page
      loadingUpdate -1
      range.max = diffs.length
    stop: ->
      document.getElementById('historyRange').removeEventListener 'change', pointers.listen
      historyBoard.clear()
    down: (e) ->
      pointers[e.pointerId] = eventToRawPoint e
      pointers[e.pointerId].transform =
        Object.assign {}, historyBoard.transform
    up: (e) ->
      delete pointers[e.pointerId]
    move: (e) ->
      return unless start = pointers[e.pointerId]
      current = eventToRawPoint e
      historyBoard.transform.x = start.transform.x +
        (current.x - start.x) / historyBoard.transform.scale
      historyBoard.transform.y = start.transform.y +
        (current.y - start.y) / historyBoard.transform.scale
      historyBoard.retransform()
  downloadSVG:
    icon: 'download-svg'
    help: 'Download/export selection or entire drawing as an SVG file'
    once: ->
      ## Temporarily remove transform for export
      root = currentBoard().root # <g>
      oldTransform = root.getAttribute 'transform'
      root.removeAttribute 'transform'
      ## Choose elements to export
      if selection.nonempty() and currentBoard() == board
        elts = currentBoard().selectedRenderedChildren()
      else
        elts = currentBoard().renderedChildren()
      ## Compute bounding box using SVG's getBBox() and getCTM()
      bbox = currentBoard().renderedBBox elts
      ## Temporarily make grid span entire drawing
      if currentBoard().grid?
        currentBoard().grid.update room.pageGrid, bbox
        elts.splice 0, 0, currentBoard().grid.grid
      ## Create SVG header
      svg = (elt.outerHTML for elt in elts).join '\n'
      .replace /&nbsp;/g, '\u00a0' # SVG doesn't support &nbsp;
      fonts = ''
      if /<text/.test svg
        for styleSheet in document.styleSheets
          if /fonts/.test styleSheet.href
            for rule in styleSheet.rules
              fonts += (rule.cssText.replace /unicode-range:.*?;/g, '') + '\n'
        fonts += '''
          text { font-family: 'Roboto Slab', serif }
          tspan.code { font-family: 'Roboto Mono', monospace }
          tspan.emph { font-style: oblique }
          tspan.strong { font-weight: bold }
          tspan.strike { text-decoration: line-through }

        '''
      svg = """
        <?xml version="1.0" encoding="utf-8"?>
        <svg xmlns="#{dom.SVGNS}" viewBox="#{bbox.min.x} #{bbox.min.y} #{bbox.max.x - bbox.min.x} #{bbox.max.y - bbox.min.y}">
        <style>
        .grid { stroke-width: 0.96; stroke: #c4e3f4 }
        #{fonts}</style>
        #{svg}
        </svg>
      """
      ## Reset transform and grid
      root.setAttribute 'transform', oldTransform if oldTransform?
      currentBoard().grid?.update()
      ## Download file
      download = document.getElementById 'download'
      download.href = URL.createObjectURL new Blob [svg], type: 'image/svg+xml'
      download.download = "cocreate-#{room.id}.svg"
      download.click()
  github:
    icon: 'github'
    help: 'Go to Github repository: documentation, source code, bug reports, and feature requests'
    once: ->
      import('/package.json').then (json) ->
        window.open json.homepage, '_blank', 'noopener'
  help:
    icon: 'question-circle'
    help: 'Open the Cocreate User Guide for online help'
    once: ->
      import('/package.json').then (json) ->
        window.open json.documentation, '_blank', 'noopener'
  pagePrev:
    icon: 'chevron-left-square'
    help: 'Go to previous page'
    hotkey: 'Page Up'
    once: pageDelta = (delta = -1) ->
      index = room.pageIndex()
      return unless index?
      index += delta
      return unless 0 <= index < room.data.pages.length
      room.changePage room.data.pages[index]
  pageNext:
    icon: 'chevron-right-square'
    help: 'Go to next page'
    hotkey: 'Page Down'
    once: -> pageDelta +1
  pageNew:
    icon: 'plus-square'
    help: 'Add new blank page after the current page'
    once: ->
      index = room?.pageIndex()
      return unless index?
      Meteor.call 'pageNew',
        room: room.id
        grid:
          if room.pageData?
            Boolean room.pageData.grid
          else
            gridDefault
      , index+1
      , (error, page) ->
        if error?
          return console.error "Failed to create new page on server: #{error}"
        room.changePage page
  pageDup:
    icon: 'clone'
    help: 'Duplicate current page'
    once: ->
      Meteor.call 'pageDup', room.page, (error, page) ->
        if error?
          return console.error "Failed to duplicate page on server: #{error}"
        room.changePage page
  pageZoomOut:
    icon: 'search-minus'
    help: 'Zoom out 20%, relative to center'
    hotkey: '-'
    once: steppedZoom = (delta = -1) ->
      factor = 1.2
      transform = currentBoard().transform
      log = Math.round(Math.log(transform.scale) / Math.log(factor))
      log += delta
      currentBoard().setScaleFixingCenter factor ** log
  pageZoomIn:
    icon: 'search-plus'
    help: 'Zoom in 20%, relative to center'
    hotkey: ['+', '=']
    once: -> steppedZoom +1
  pageZoomReset:
    icon: 'search-one'
    help: 'Reset zoom to 100%'
    hotkey: '0'
    once: ->
      currentBoard().setScaleFixingCenter 1
  pageZoomFit:
    icon: 'zoom-fit'
    help: 'Zoom to fit screen to all objects or selection'
    hotkey: '9'
    once: ->
      ## Choose elements to contain
      if selection.nonempty() and currentBoard() == board
        elts = currentBoard().selectedRenderedChildren()
      else
        elts = currentBoard().renderedChildren()
      return unless elts.length
      currentBoard().zoomToFit currentBoard().renderedBBox elts
  pageSpacer: {}
  fill:
    palette: 'colors'
    help: 'Toggle filling of rectangles and ellipses. <kbd>Shift</kbd>-click a color to set fill color.'
    init: (div) ->
      div.innerHTML =
        (icons.svgIcon (icons.modIcon 'tint', fill: 'currentColor'),
                       id: 'fillOn') +
        (icons.svgIcon (icons.modIcon 'tint-slash', fill: 'currentColor'),
                       id: 'fillOff')
      updateFill()
    once: ->
      currentFillOn = not currentFillOn
      updateFill()
      if selection.nonempty()
        selection.edit 'fill', if currentFillOn then currentFill else null
      else
        selectDrawingTool()

currentTool = 'pan'
export drawingTools =
  pen: true
  segment: true
  rect: true
  ellipse: true
  text: true
lastDrawingTool = 'pen'
hotkeys = {}

export currentBoard = ->
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
export defaultColor = 'black'
currentColor = defaultColor
colorMap = {}
colorMap[color] = true for color in colors

widths = [
  1
  2
  3
  4
  5
  6
  7
]
for width in widths
  hotkeys[width] = do (width) -> -> selectWidth width
currentWidth = 5

## These numbers are based on powers of 1.2 starting from 16
## (the site's default font size)
fontSizes = [
  12
  16
  19
  23
  28
  33
  40
]
currentFontSize = 19

## Maps a PointerEvent with `pressure` attribute to a `w` multiplier to
## multiply with the "natural" width of the pen.
pressureW = (e) -> 0.5 + e.pressure
#pressureW = (e) -> 2 * e.pressure
#pressureW = (e) ->
#  t = e.pressure ** 3
#  0.5 + (1.5 - 0.5) * t

eventToPoint = (e) ->
  {x, y} = dom.svgPoint board.svg, e.clientX, e.clientY, board.root
  {x, y}

eventToConstrainedPoint = (e, origin) ->
  pt = eventToPoint e
  ## When holding Shift, constrain 1:1 aspect ratio from origin, following
  ## the largest delta and maintaining their signs (like Illustrator).
  if e.shiftKey
    dx = pt.x - origin.x
    dy = pt.y - origin.y
    adx = Math.abs dx
    ady = Math.abs dy
    if adx > ady
      pt.y = origin.y + adx * Math.sign dy
    else if adx < ady
      pt.x = origin.x + ady * Math.sign dx
  pt

eventToOrthogonalPoint = (e, origin) ->
  pt = eventToPoint e
  ## Force horizontal/vertical line from origin when holding shift
  if e.shiftKey
    dx = Math.abs pt.x - origin.x
    dy = Math.abs pt.y - origin.y
    if dx > dy
      pt.y = origin.y
    else
      pt.x = origin.x
  pt

snapPoint = (pt) ->
  if room.gridSnap.get()
    pt.x = gridSize * Math.round pt.x / gridSize
    pt.y = gridSize * Math.round pt.y / gridSize
  pt

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

symmetricPoint = (pt, origin) ->
  x: 2*origin.x - pt.x
  y: 2*origin.y - pt.y

restrictTouch = (e) ->
  not allowTouch.get() and \
  e.pointerType == 'touch' and \
  currentTool of drawingTools

pointerEvents = ->
  dom.listen [board.svg, historyBoard.svg],
    pointerdown: (e) ->
      e.preventDefault()
      return if restrictTouch e
      text.blur() for text in document.querySelectorAll 'input'
      window.focus()  # for getting keyboard focus when <iframe>d
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
    wheel: (e) ->
      e.preventDefault()
      transform = currentBoard().transform
      {deltaX, deltaY} = e
      ## Convert Shift + 1D wheel into horizontal scroll.  MacOS seems to do
      ## this automatically (hence the deltaX check) but Windows doesn't.
      if not e.ctrlKey and e.shiftKey and e.deltaX == 0
        [deltaX, deltaY] = [deltaY, deltaX]
      switch e.deltaMode
        #when WheelEvent.DOM_DELTA_PIXEL
        when WheelEvent.DOM_DELTA_LINE
          deltaX *= 50
          deltaY *= 50
        when WheelEvent.DOM_DELTA_PAGE
          deltaX *= board.bbox.width
          deltaY *= board.bbox.height
      if e.ctrlKey
        ## Ensure zoom-out motion is inverse of equivalent zoom-in
        factor = 1 + 0.01 * Math.abs deltaY
        factor = 1/factor if deltaY > 0
        currentBoard().setScaleFixingPoint transform.scale * factor,
          x: e.offsetX
          y: e.offsetY
      else
        transform.x -= deltaX / transform.scale
        transform.y -= deltaY / transform.scale
        currentBoard().retransform()
  dom.listen board.svg,
    pointermove: (e) ->
      return unless room?
      return unless room.page?
      return if restrictTouch e
      remote =
        name: name.get().trim()
        room: room.id
        page: room.page
        tool: currentTool
        color: currentColor
        cursor: eventToPointW e
      remote.fill = currentFill if currentFillOn
      remotes.update remote

## Resets the selection, and if the current tool supports selection,
## sets the selection to the specified array of object IDs
## (as e.g. returned by `UndoStack.undo` and `UndoStack.redo`).
## Does nothing if `objIds` is undefined (as when `undo` or `redo` failed).
export setSelection = (objIds) ->
  return unless objIds?
  selectHighlightReset()
  tools[currentTool]?.select? objIds

historyAdvance = (delta) ->
  range = document.getElementById 'historyRange'
  value = parseInt range.value
  range.value = value + delta
  event = document.createEvent 'HTMLEvents'
  event.initEvent 'change', false, true
  range.dispatchEvent event

setInterval ->
  board?.remotesRender?.timer()
, 1000

loadingCount = 0
loadingUpdate = (delta) ->
  loadingCount += delta
  loading = loadingCount > 0
  dom.classSet document.getElementById('loading'), 'loading', loading
  unless loading
    updateBadRoom()

updateBadRoom = ->
  bad = not (room? and
    (data = room.data ? Rooms.findOne room.id)? and
    data.pages?.length
  )
  dom.classSet document.getElementById('badRoom'), 'show', bad
  if bad
    room?.stop()
    room = null

subscribe = (...args) ->
  delta = 1
  loadingUpdate delta
  done = ->
    loadingUpdate -delta
    delta = 0
  Meteor.subscribe ...args,
    onReady: done
    onStop: done

class Room
  constructor: (@id, @board) ->
    @changePage null
    @sub = subscribe 'room', @id
    @auto = Tracker.autorun =>
      @data = Rooms.findOne @id
      return unless @data?
      Tracker.nonreactive =>  # depend only on room data
        updateBadRoom()
        if @page?
          @updatePageNum()  # update page number if set of pages changes
        else
          @changePage @data.pages?[0]  # start on first page if not on a page
        document.getElementById('numPages').innerHTML =
          @data.pages?.length ? '?'
    @gridSnap = new storage.Variable "#{@id}.gridSnap", false, updateGridSnap
  updateUI: ->
    updateGridSnap()
  stop: ->
    @auto.stop()
    @observe?.stop()
    @sub.stop()
    @pageAuto?.stop()
    @roomObserveObjects?.stop()
    @roomObserveRemotes?.stop()
  changePage: (page) ->
    # pageAttributes should maybe be in separate Page class
    @pageAuto?.stop()
    @page = page
    tools[currentTool]?.stop?()
    @objectsObserver?.stop()
    @remotesObserver?.stop()
    @objectsObserver = @remotesObserver = null
    if @page?
      @observeObjects()  # sets @objectsObserver
      @observeRemotes()  # sets @remotesObserver
    else
      @board.clear()
    dom.classSet document.body, 'nopage', not @page?
      # in particular, disable pointer events when no page
    @updatePageNum()
    selectTool null
    @pageGrid = null
    @pageAuto = Tracker.autorun =>
      @pageData = Pages.findOne @page
      Tracker.nonreactive =>  # depend only on page data
        if @pageGrid != @pageData?.grid
          @pageGrid = @pageData?.grid
          dom.classSet document.querySelector('.tool[data-tool="grid"]'),
            'active', @pageGrid
          @board.grid?.update()
  updatePageNum: ->
    pageNumber = @pageIndex()
    pageNumber++ if pageNumber?
    document.getElementById('pageNum').value = pageNumber ? '?'
  pageIndex: ->
    return unless @data?.pages?
    index = @data.pages.indexOf @page
    return if index < 0
    index
  observeObjects: ->
    @render?.stop()
    @render = render = new RenderObjects @board.root
    @board.clear()
    @board.grid = new Grid @
    @objectsObserver = Objects.find
      room: @id
      page: @page
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
          text: obj.text != old.text
          fontSize: obj.fontSize != old.fontSize
      removed: (obj) ->
        render.delete obj
  observeRemotes: ->
    @board.remotesRender = remotesRender = new RenderRemotes @
    @remotesObserver = Remotes.find
      room: @id
    .observe
      added: (remote) -> remotesRender.render remote
      changed: (remote, oldRemote) -> remotesRender.render remote, oldRemote
      removed: (remote) -> remotesRender.delete remote

changeRoom = (roomId) ->
  return if roomId == room?.id
  room?.stop()
  if roomId?
    room = new Room roomId, board
    room.updateUI()
  else
    room = null
    updateBadRoom()

updateRoomLink = null
urlChange = ->
  updateRoomLink?()
  if document.location.pathname == '/'
    Meteor.call 'roomNew',
      grid: gridDefault
    , (error, data) ->
      if error?
        updateBadRoom() # should display visible error message
        return console.error "Failed to create new room on server: #{error}"
      history.replaceState null, 'new room', "/r/#{data.room}"
      urlChange()
  else if match = document.location.pathname.match /^\/r\/(\w*)$/
    changeRoom match[1]
  else
    changeRoom null

paletteTools = ->
  tooltip = null  # currently open tooltip
  removeTooltip = ->
    tooltip?.remove()
    tooltip = null
  toolsDiv = document.getElementById 'tools'
  pagesDiv = document.getElementById 'pages'
  align = 'top'
  for tool, {icon, help, hotkey, init, palette} of tools
    palette ?= if tool.startsWith 'page' then 'pages' else 'tools'
    container = palette = document.getElementById palette
    while palette.classList.contains 'subpalette'
      palette = palette.parentNode
    orientation = ''
    if palette.classList.contains 'horizontal'
      orientation = 'horizontal'
      if palette.classList.contains 'top'
        orientation += ' top'
      else if palette.classList.contains 'bottom'
        orientation += ' bottom'
    else if palette.classList.contains 'vertical'
      orientation = 'vertical'
    if tool.startsWith('spacer') or tool.endsWith('Spacer')
      container.appendChild dom.create 'div', class: 'spacer'
      align = 'bottom'
    else
      container.appendChild div = dom.create 'div', null,
        className: 'tool'
        dataset: tool: tool
        innerHTML: if icon then icons.svgIcon \
          icons.modIcon icon, fill: 'currentColor'
      ,
        click: (e) ->
          removeTooltip()
          selectTool e.currentTarget.dataset.tool
      if help
        if hotkey
          hotkey = [hotkey] unless Array.isArray hotkey
          help += """<span class="hotkeys">"""
          for key in hotkey
            help += """<kbd class="hotkey">#{key}</kbd>"""
            key = key.replace /\s/g, ''
            hotkeys[key] = do (tool) -> -> selectTool tool
          help += """</span>"""
        do (div, align, orientation, help) ->
          dom.listen div,
            pointerenter: ->
              removeTooltip()
              divBBox = div.getBoundingClientRect()
              document.body.appendChild tooltip = dom.create 'div', null,
                className: "tooltip align-#{align} #{orientation}"
                innerHTML: help
                style:
                  if orientation == 'vertical'
                    if align == 'top'
                      top: "#{divBBox.top}px"
                    else # bottom
                      bottom: "calc(100% - #{divBBox.bottom}px)"
                  else # horizontal top/bottom
                    left: "calc(#{divBBox.left + 0.5 * divBBox.width}px - 0.5 * var(--tooltip-width))"
              ,
                pointerenter: removeTooltip
            pointerleave: removeTooltip
      init? div
  ## Move name entry to end
  document.getElementById('pages').appendChild document.getElementById 'name'

setCursor = (target, icon, xFrac, yFrac) ->
  if fancyCursor.get()
    options = {}
    if dark.get()
      options.style = 'filter:invert(1) hue-rotate(180deg)'
    icons.setCursor target, icon, xFrac, yFrac, options
  else
    target.style.cursor = null

updateCursor = ->
  if currentTool of drawingTools
    ## Drawing tools' cursors depend on the current color
    if currentTool of drawingTools
      setCursor board.svg,
        drawingToolIcon(currentTool, currentColor,
          if currentFillOn then currentFill),
        ...tools[currentTool].hotspot
  else if currentTool == 'history'
    setCursor document.getElementById('historyRange'),
      tools['history'].icon, ...tools['history'].hotspot
    setCursor document.getElementById('historyBoard'),
      tools['pan'].icon, ...tools['pan'].hotspot
  else
    setCursor board.svg, tools[currentTool].icon,
      ...tools[currentTool].hotspot

lastTool = null
selectTool = (tool, options) ->
  {noStart, noStop} = options if options?
  if tools[tool]?.once?
    return tools[tool].once?()
  if tool == currentTool == 'history'  # treat history as a toggle
    tool = lastTool
  return if tool == currentTool
  tools[currentTool]?.stop? tool unless noStop
  document.body.classList.remove "tool-#{currentTool}" if currentTool
  if tool?  # tool == null means initialize already set currentTool
    lastTool = currentTool
    currentTool = tool
  dom.select '.tool', "[data-tool='#{currentTool}']"
  updateCursor()
  pointers = {}  # tool-specific data
  tools[currentTool]?.start?() unless noStart
  document.body.classList.add "tool-#{currentTool}" if currentTool
  lastDrawingTool = currentTool if currentTool of drawingTools
selectDrawingTool = ->
  unless currentTool of drawingTools
    selectTool lastDrawingTool

updateFill = ->
  fillTool = document.querySelector('.tool[data-tool="fill"]')
  dom.classSet fillTool, 'active', currentFillOn
  fillTool.style.color = currentFill
  updateCursor()

paletteColors = ->
  colorsDiv = document.getElementById 'colors'
  for color in colors
    colorsDiv.appendChild dom.create 'div', null,
      className: 'color attrib'
      style: backgroundColor: color
      dataset: color: color
    ,
      click: onColor = (e) ->
        (if e.shiftKey then selectFill else selectColor) \
          e.currentTarget.dataset.color
  colorsDiv.appendChild dom.create 'div', null,
    id: 'customColor'
    className: 'color attrib'
    dataset: color: '#808080'
    style: backgroundColor: '#808080'
  ,
    click: onColor
  , [
    dom.create 'div', null,
      className: 'set'
    ,
      click: (e) ->
        e.stopPropagation()
        customColorInput.click()
    customColorInput = dom.create 'input', null,
      type: 'color'
      id: 'customColorInput'
    ,
      input: (e) ->
        selectColor customColorInput.value
  ]

widthSize = 22
paletteWidths = ->
  widthsDiv = document.getElementById 'widths'
  for width in widths
    widthsDiv.appendChild dom.create 'div', null,
      className: 'width attrib'
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
          class: 'label'
          x: widthSize/2
          y: widthSize*2/3
        , null, null, [
          document.createTextNode "#{width}"
        ]
      ]
    ]

fontSizeSize = 28
paletteFontSizes = ->
  fontSizesDiv = document.getElementById 'fontSizes'
  for fontSize in fontSizes
    fontSizesDiv.appendChild dom.create 'div', null,
      className: 'fontSize attrib'
      dataset: fontSize: fontSize
    ,
      click: (e) -> selectFontSize e.currentTarget.dataset.fontSize
    , [
      dom.create 'svg',
        viewBox: "#{-fontSizeSize/2} 0 #{fontSizeSize} #{fontSizeSize}"
        width: fontSizeSize
        height: fontSizeSize
      , null, null
      , [
        dom.create 'text',
          y: fontSizeSize*0.5
          style: "font-size:#{fontSize}px"
        , null, null, [
          document.createTextNode 'A'
        ]
        dom.create 'text',
          class: 'label'
          y: fontSizeSize*0.875
        , null, null, [
          document.createTextNode "#{fontSize}"
        ]
      ]
    ]

export drawingToolIcon = (tool, color, fill) ->
  icon = tools[tool]?.icon
  return icon unless icon?
  attr = fill: color
  if tool == 'pen' or color == 'white'
    Object.assign attr,
      stroke: 'black'
      'stroke-width': '15'
      'stroke-linecap': 'round'
      'stroke-linejoin': 'round'
  icon = icons.modIcon icon, attr
  if fill and iconFill = tools[tool].iconFill
    icon = icons.stackIcons [icon, icons.modIcon iconFill, fill: fill]
  icon

export selectColor = (color, keepTool, skipSelection) ->
  currentColor = color if color?
  if currentColor of colorMap
    dom.select '.color', "[data-color='#{currentColor}']"
  else
    dom.select '.color', '#customColor'
    customColor = document.getElementById 'customColor'
    customColor.style.backgroundColor = currentColor
    customColor.dataset.color = currentColor
    document.getElementById('customColorInput').value = currentColor
  document.documentElement.style.setProperty '--currentColor', currentColor
  if not skipSelection and selection.nonempty()
    selection.edit 'color', currentColor
    keepTool = true
  selectDrawingTool() unless keepTool
  updateCursor()

export selectFill = (color, fromSelection) ->
  currentFill = color
  currentFillOn = true
  updateFill()
  return if fromSelection
  if selection.nonempty()
    selection.edit 'fill', currentFill
  else
    selectDrawingTool()

export selectFillOff = ->
  currentFillOn = false
  updateFill()

export selectWidth = (width, keepTool, skipSelection) ->
  currentWidth = parseFloat width if width?
  if not skipSelection and selection.nonempty()
    selection.edit 'width', currentWidth
    keepTool = true
  selectDrawingTool() unless keepTool
  dom.select '.width', "[data-width='#{currentWidth}']"

export selectFontSize = (fontSize, skipSelection) ->
  currentFontSize = parseFloat fontSize if fontSize?
  if not skipSelection and selection.nonempty()
    selection.edit 'fontSize', currentFontSize
  dom.select '.fontSize', "[data-font-size='#{currentFontSize}']"

paletteSize = ->
  parseFloat (getComputedStyle document.documentElement
  .getPropertyValue '--palette-size')

resize = (reps = 1) ->
  tooltip?.remove()
  for [id, attrib, dimen] in [
    ['tools', '--palette-left-width', 'Width']
    ['attribs', '--palette-bottom-height', 'Height']
    ['pages', '--palette-top-height', 'Height']
  ]
    div = document.getElementById id
    if 0 <= attrib.indexOf 'width'
      scrollbar = div.offsetWidth - div.clientWidth
    else if 0 <= attrib.indexOf 'height'
      scrollbar = div.offsetHeight - div.clientHeight
    document.documentElement.style.setProperty attrib,
      "#{scrollbar + paletteSize()}px"
  board.resize()
  historyBoard.resize()
  setTimeout (-> resize reps-1), 0 if reps

Meteor.startup ->
  document.getElementById('loading').innerHTML = icons.svgIcon \
    icons.modIcon 'spinner', fill: 'currentColor'
  board = new Board 'board'
  historyBoard = new Board 'historyBoard'
  resize()
  selection = new Selection board
  paletteTools()
  paletteWidths()
  paletteFontSizes()
  paletteColors()
  selectTool()
  selectColor null, true
  selectWidth null, true
  selectFontSize null
  pointerEvents()
  dom.listen window,
    resize: resize
    popstate: urlChange
  , true # call now
  oldPointers = null
  dom.listen window,
    keydown: (e) ->
      switch e.key
        when 'z', 'Z'
          if e.ctrlKey or e.metaKey
            if e.shiftKey
              tools.redo.once()
            else
              tools.undo.once()
        when 'y', 'Y'
          if e.ctrlKey or e.metaKey
            tools.redo.once()
        when 'Delete', 'Backspace'
          selection.delete()
        when ' '  ## pan via space-drag
          if currentTool not in ['pan', 'history']
            spaceDown = true
            oldPointers = pointers
            selectTool 'pan', noStop: true
        when 'd', 'D'  ## duplicate
          if (e.ctrlKey or e.metaKey) and selection.nonempty()
            e.preventDefault()  # ctrl-D bookmarks on Chrome
            selection.duplicate()
        when 'Escape'
          if currentTool == 'history'
            selectTool 'history'  # escape history view by toggling
        else
          ## Prevent e.g. ctrl-1 browser shortcut (go to tab 1) from also
          ## triggering width 1 hotkey.
          return if e.ctrlKey or e.metaKey
          if e.key of hotkeys
            hotkeys[e.key]()
          else
            hotkeys[e.key.toLowerCase()]?()
    keyup: (e) ->
      switch e.key
        when ' '  ## end of pan via space-drag
          if spaceDown
            selectTool lastTool, noStart: true
            pointers = oldPointers
            spaceDown = false

  dom.listen pageNum = document.getElementById('pageNum'),
    keydown: (e) ->
      e.stopPropagation() # avoid width setting hotkey
    change: (e) ->
      return unless room?.data?.pages?.length
      page = parseInt pageNum.value
      if isNaN page
        room.updatePageNum()
      else
        page = Math.min room?.data.pages.length, Math.max 1, page
        room.changePage room?.data.pages[page-1]

  dom.listen nameInput = document.getElementById('name'),
    keydown: (e) ->
      e.stopPropagation() # avoid width setting hotkey
    input: (e) ->
      name.set nameInput.value
  ## Coop protocol
  dom.listen window,
    message: (e) ->
      return unless e.data?.coop
      if typeof e.data.user?.fullName == 'string'
        name.setTemp e.data.user.fullName
        name.update()
      if typeof e.data.theme?.dark == 'boolean'
        dark.setTemp e.data.theme.dark
        dark.update()
  ## window.opener can be null, but window.parent defaults to window
  parent = window.opener ? window.parent
  if parent? and parent != window
    parent.postMessage
      coop: 1
      status: 'ready'
    , '*'

  document.getElementById('roomLinkStyle').innerHTML =
    Meteor.absoluteUrl 'r/ABCD23456789vwxyz'
  document.getElementById('newRoomLink').setAttribute 'href',
    Meteor.absoluteUrl()

## Cocreate doesn't perform great in combination with Meteor DevTools;
## prevent it from applying its hooks.
window.__devtools = true
