import React from 'react'

import {defineTool} from './defineTool'
import {currentColor} from './color'
import {currentWidth} from './width'
import {currentBoard, mainBoard} from '../Board'
import {highlighterClear} from '../Selection'
import {Ctrl, Alt, firefox} from '../lib/platform'

defineTool
  name: 'pan'
  category: 'mode'
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

defineTool
  name: 'select'
  category: 'mode'
  icon: 'mouse-pointer'
  hotspot: [0.21875, 0.03515625]
  help: <>Select objects by dragging rectangle {if firefox then <i>(not currently supported on Firefox)</i>} or clicking on individual objects (toggling multiple if holding <kbd>Shift</kbd>). Then change their color/width, move by dragging (<kbd>Shift</kbd> for horizontal/vertical), copy via <kbd>{Ctrl}-C</kbd>, cut via <kbd>{Ctrl}-X</kbd>, paste via <kbd>{Ctrl}-V</kbd>, duplicate via <kbd>{Ctrl}-D</kbd>, or <kbd>Delete</kbd> them.</>
  hotkey: 's'
  start: ->
    pointers.objects = {}
  stop: selectHighlightReset = (nextTool) ->
    mainBoard.selection.clear() unless nextTool in ['text', 'image']
    highlighterClear()
  down: (e) ->
    selection = mainBoard.selection
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
      selection = mainBoard.selection
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
    mainBoard.selection.addId id for id in ids

defineTool
  name: 'pen'
  category: 'mode'
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
        color: currentColor.get()
        width: currentWidth.get()
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

defineTool
  name: 'segment'
  category: 'mode'
  icon: 'segment'
  hotspot: [0.0625, 0.9375]
  help: <>Draw straight line segment between endpoints (drag). Hold <kbd>Shift</kbd> to constrain to horizontal/vertical, <kbd>{Alt}</kbd> to center at first point.</>
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
        color: currentColor.get()
        width: currentWidth.get()
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

defineTool
  name: 'rect'
  category: 'mode'
  icon: 'rect'
  iconFill: 'rect-fill'
  hotspot: [0.0625, 0.883]
  help: <>Draw axis-aligned rectangle between endpoints (drag). Hold <kbd>Shift</kbd> to constrain to square, <kbd>{Alt}</kbd> to center at first point.</>
  hotkey: 'r'
  down: (e) ->
    return if pointers[e.pointerId]
    origin = snapPoint eventToPoint e
    object =
      room: room.id
      page: room.page
      type: 'rect'
      pts: [origin, origin]
      color: currentColor.get()
      width: currentWidth.get()
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

defineTool
  name: 'ellipse'
  category: 'mode'
  icon: 'ellipse'
  iconFill: 'ellipse-fill'
  hotspot: [0.201888, 0.75728]
  help: <>Draw axis-aligned ellipsis inside rectangle between endpoints (drag). Hold <kbd>Shift</kbd> to constrain to circle, <kbd>{Alt}</kbd> to center at first point.</>
  hotkey: 'o'
  down: (e) ->
    return if pointers[e.pointerId]
    origin = snapPoint eventToPoint e
    object =
      room: room.id
      page: room.page
      type: 'ellipse'
      pts: [origin, origin]
      color: currentColor.get()
      width: currentWidth.get()
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

defineTool
  name: 'eraser'
  category: 'mode'
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

defineTool
  name: 'text'
  category: 'mode'
  icon: 'text'
  hotspot: [.77, .89]
  help: <>Type text (click location or existing text, then type at bottom), including Markdown *<i>italic</i>*, **<b>bold</b>**, ***<b><i>bold italic</i></b>***, `<code>code</code>`, ~~<s>strike</s>~~, and LaTeX $math$, $$displaymath$$</>
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
              type: 'edit'
              id: pointers.text
              before: text: oldText
              after: text: text
          switch pointers.undoable.type
            when 'new'
              pointers.undoable.obj.text = text
            when 'edit'
              pointers.undoable.after.text = text
  start: ->
    pointers.highlight = new Highlighter board, 'text'
    if (ids = mainBoard.selection.ids()).length == 1 and
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
    mainBoard.selection.clear() unless nextTool == 'select'
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
      mainBoard.selection.add h
      mainBoard.selection.setAttributes()
      text = Objects.findOne(pointers.text)?.text ? ''
    else
      pointers.text = Meteor.apply 'objectNew', [
        room: room.id
        page: room.page
        type: 'text'
        pts: [snapPoint eventToPoint e]
        text: text = ''
        color: currentColor.get()
        fontSize: currentFontSize.get()
      ], returnStubValue: true
      mainBoard.selection.addId pointers.text
      undoStack.push pointers.undoable =
        type: 'new'
        obj: Objects.findOne pointers.text
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
      mainBoard.selection.addId pointers.text
      input = document.getElementById 'textInput'
      input.value = obj.text
      input.disabled = false
      ## Giving the input focus makes it hard to do repeated global undo/redo;
      ## instead the text-entry box does its own undo/redo.
      #input.focus()

defineTool
  name: 'image'
  category: 'mode'
  icon: 'image'
  hotspot: [0.21875, 0.34375]
  help: 'Embed image (SVG, JPG, PNG, etc.) on web by entering its URL at bottom. Click on existing image to modify URL, or a point to specify location. You can also paste an image URL from the clipboard, or drag an image from a webpage (without needing this tool).'
  init: ->
    input = document.getElementById 'urlInput'
    dom.listen input,
      keydown: (e) ->
        e.stopPropagation() # avoid hotkeys
        e.target.blur() if e.key == 'Escape'
        updateUrl e if e.key == 'Enter'  # force rechecking URL
      input: (e) ->
        input.className = 'pending'
      change: updateUrl = debounce (e) ->
        url = input.value
        old = if pointers.image then Objects.findOne pointers.image
        #return if url == old?.url
        obj = await tryAddImageUrl url, objOnly: true
        input.className = if obj? then 'success' else 'error'
        return unless obj?
        unless old?
          obj.pts = [pointers.point ?
                      snapPoint board.relativePoint 0.25, 0.25]
          undoStack.pushAndDo pointers.undoable =
            type: 'new'
            obj: obj
          pointers.image = obj._id
        else
          return if obj.url == old.url and
            obj.credentials == old.credentials and obj.proxy == old.proxy
          edit =
            id: pointers.image
            url: obj.url
            credentials: obj.credentials
            proxy: obj.proxy
          Meteor.call 'objectEdit', edit
          delete edit.id
          unless pointers.undoable?
            undoStack.push pointers.undoable =
              type: 'edit'
              id: pointers.image
              before:
                url: old.url
                credentials: old.credentials
                proxy: old.proxy
              after: edit
          switch pointers.undoable.type
            when 'new'
              Object.assign pointers.undoable.obj, edit
            when 'edit'
              Object.assign pointers.undoable.after, edit
      , 50
  start: ->
    pointers.highlight = new Highlighter board, 'image'
    if (ids = mainBoard.selection.ids()).length == 1 and
        (obj = Objects.findOne(ids[0]))?.type == 'image'
      pointers.image = obj._id
      input = document.getElementById 'urlInput'
      input.value = obj.url ? ''
      input.className = ''
      setTimeout (-> input.focus()), 0  # wait for input to show
    else
      tools.image.stop()
  stop: (nextTool, keepHighlight) ->
    input = document.getElementById 'urlInput'
    input.value = ''
    input.className = ''
    mainBoard.selection.clear() unless nextTool == 'select'
    pointers.highlight?.clear() unless keepHighlight
    return unless (id = pointers.image)?
    if (object = Objects.findOne id)?
      unless object.url
        undoStack.remove pointers.undoable
        Meteor.call 'objectDel', id
    pointers.undoable = null
    pointers.image = null
    pointers.point = null
  up: (e) ->
    return unless e.type == 'pointerup' # ignore pointerleave
    ## Stop editing any previous image object.
    tools.image.stop null, true
    h = pointers.highlight
    unless h.id?
      if (target = h.eventTop e)?
        h.highlight target
    if h.id?
      pointers.image = h.id
      mainBoard.selection.add h
      mainBoard.selection.setAttributes()
      url = Objects.findOne(pointers.image)?.url ? ''
    else
      pointers.point = snapPoint eventToPoint e
      url = ''
    input = document.getElementById 'urlInput'
    input.value = url
    input.className = ''
    input.focus()
  move: (e) ->
    h = pointers.highlight
    target = h.eventTop e
    if target? and Objects.findOne(target.dataset.id).type == 'image'
      h.highlight target
    else
      h.clear()
  select: (ids) ->
    return unless ids.length == 1
    return if pointers.image == ids[0]
    obj = Objects.findOne ids[0]
    return unless obj?.type == 'image'
    tools.image.stop()
    pointers.image = obj._id
    mainBoard.selection.addId pointers.image
    input = document.getElementById 'urlInput'
    input.value = obj.url

defineTool
  name: 'history'
  icon: 'history'
  hotspot: [0.5, 0.5]
  help: 'Time travel to the past (by dragging the bottom slider)'
  start: ->
    historyObjects = {}
    range = document.getElementById 'historyRange'
    range.value = 0
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
          when 'pen', 'poly', 'rect', 'ellipse', 'text', 'image'
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
