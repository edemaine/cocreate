import React from 'react'
import {render} from 'react-dom'
import {Tracker} from 'meteor/tracker'
import debounce from 'debounce'

import '../lib/main'
import './lib/polyfill'
import {validUrl, proxyUrl} from '../lib/url'
import icons from './lib/icons'
import dom from './lib/dom'
import remotes from './lib/remotes'
import storage from './lib/storage'
import throttle from './lib/throttle'
import {meteorCallPromise} from '/lib/meteorPromise'
import './tools/tools'
import {App} from './App'
import {Board} from './Board'
import {Grid, gridSize} from './Grid'
import {RenderObjects} from './RenderObjects'
import {RenderRemotes} from './RenderRemotes'
import {Selection, Highlighter, highlighterClear} from './Selection'
import {UndoStack} from './UndoStack'

board = historyBoard = null # Board objects
eraseDist = 2   # require movement by this many pixels before erasing swipe
dragDist = 2    # require movement by this many pixels before select drags
export undoStack = new UndoStack
export room = null
spaceDown = false

distanceThreshold = (p, q, t) ->
  return false if not p or not q
  return true if p == true or q == true
  dx = p.clientX - q.clientX
  dy = p.clientY - q.clientY
  dx * dx + dy * dy >= t * t

export pointers = {}   # maps pointerId to tool-specific data
export tools =
  pageSpacer: {}

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
      pressureW e
    else
      1
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
        tool: currentTool.get()
        color: currentColor.get()
        cursor: eventToPointW e
      remote.fill = currentFill.get() if currentFillOn.get()
      remotes.update remote

dragEvents = ->
  dragDepth = 0
  all = (e) ->
    e.preventDefault()
    e.dataTransfer.dropEffect = 'copy'
  dom.listen board.svg,
    dragenter: (e) ->
      all e
      return if dragDepth++
      ## Entering for the first time
      document.getElementById('dragzone').classList.add 'drag'
    dragover: (e) ->
      all e
      #return unless dragDepth
    dragleave: (e) ->
      all e
      return if --dragDepth
      ## Leaving for the last time
      document.getElementById('dragzone').classList.remove 'drag'
    drop: (e) ->
      all e
      dragDepth = 0
      document.getElementById('dragzone').classList.remove 'drag'
      tryAddImage e.dataTransfer.items,
        pts: [snapPoint eventToPoint e]

tryAddImage = (items, options) ->
  ## HTML <img> tag (as from dragging images) or <a href> tag
  ## (without nested <a> links, as from dragging links)
  ## are highest priority.
  for item in items when item.type == 'text/html'
    html = await new Promise (done) -> item.getAsString done
    match = ///^\s* <img\b [^<>]* \b src \s*=\s* ("[^"]*"|'[^']*')
                      [^<>]*> \s*$///i.exec(html) or
    ///^\s* <a\b [^<>]* \b href \s*=\s* ("[^"]*"|'[^']*')
              [^<>]*> ([^]*) </a> \s*$///i.exec(html)
    if match? and not (match[2] and ///</a>///i.test match[2])
      url = match[1][1...match[1].length-1]
      return image if image = await tryAddImageUrl url, options
  ## Next check for plain text that consists solely of a URL
  for item in items when item.type == 'text/plain'
    text = await new Promise (done) -> item.getAsString done
    text = text.trim()
    return image if image = await tryAddImageUrl text, options
  false

## Asynchronously try to verify URL points to an image, and if so,
## add it to the current room and page and return the new object ID.
## `options` should not be provided; instead, it will be modified
## automatically to find a workable method.
tryAddImageUrl = (url, options = {}) ->
  return unless validUrl url
  fetchUrl =
    if options.proxy
      proxyUrl url
    else
      url
  fetchOptions =
    cache: 'reload' # don't use cache while testing whether need credentials
    mode: 'cors'
    credentials: if options.credentials then 'include' else 'same-origin'
  ## Test whether image will load successfully by manually running a CORS
  ## preflight test (OPTIONS); then load content-type via HEAD request.
  try
    for method in ['OPTIONS', 'HEAD']
      response = await fetch fetchUrl, Object.assign {method}, fetchOptions
  catch e
    if Meteor.settings.public['cors-anywhere'] and
        not options.proxy and not options.credentials
      console.log "URL #{fetchUrl} failed to load, likely blocked by CORS; trying again with proxy"
      return tryAddImageUrl url, Object.assign options, proxy: true
    else
      console.log "URL #{fetchUrl} failed to load (#{e}) :-("
      return
  ## Status: Unauthorized or Forbidden -> try again with credentials
  ## (e.g. for Coauthor images)
  if response.status in [401, 403] and
     not options.credentials and not options.proxy
    console.log "URL #{fetchUrl} returned status #{response.status} from server; trying again with credentials"
    return tryAddImageUrl url, Object.assign options, credentials: true
  unless response.status in [200, 204]
    console.log "URL #{fetchUrl} returned status #{response.status} from server :-("
    return
  contentType = response.headers.get 'content-type'
  unless /^image\//.test contentType
    console.log "URL #{fetchUrl} has content-type #{contentType} which is not a supported image type"
    return
  obj =
    room: room.id
    page: room.page
    type: 'image'
    url: url
    credentials: Boolean options.credentials
    proxy: Boolean options.proxy
  for key in ['pts', 'tx', 'ty']
    if key of options
      obj[key] = options[key]
  unless options.objOnly
    undoStack.pushAndDo
      type: 'new'
      obj: obj
  obj

## Resets the selection, and if the current tool supports selection,
## sets the selection to the specified array of object IDs
## (as e.g. returned by `UndoStack.undo` and `UndoStack.redo`).
## Does nothing if `objIds` is undefined (as when `undo` or `redo` failed).
export setSelection = (objIds) ->
  return unless objIds?
  selectHighlightReset()
  tools[currentTool]?.select? objIds

setInterval ->
  board?.remotesRender?.timer()
, 1000

Meteor.startup ->
  render <App/>, document.getElementById 'react-root'
  ###
  selectTool()
  pointerEvents()
  dragEvents()
  ###
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
          if document.getElementById('qrCode').classList.contains 'show'
            tools.linkRoom.once()  # QR overlay toggle
          else if currentTool == 'history'
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
    copy: onCopy = (e) ->
      ## Ignore paste operations within text boxes
      return if e.target.tagName in ['INPUT', 'TEXTAREA']
      return unless selection.nonempty()
      e.preventDefault()
      e.clipboardData.setData 'application/cocreate-objects', selection.json()
      e.clipboardData.setData 'image/svg+xml',
        tools.downloadSVG.once null, false
      true
    cut: (e) ->
      if onCopy e
        selection.delete()
    paste: (e) ->
      ## Ignore paste operations within text boxes
      return if e.target.tagName in ['INPUT', 'TEXTAREA']
      e.preventDefault()
      if json = e.clipboardData.getData 'application/cocreate-objects'
        objects =
          for obj in JSON.parse json
            delete obj._id
            delete obj.created
            delete obj.updated
            obj.room = room.id
            obj.page = room.page
            obj._id = Meteor.apply 'objectNew', [obj], returnStubValue: true
            obj
        undoStack.push
          type: 'multi'
          ops:
            for obj in objects
              type: 'new'
              obj: obj
        selectTool 'select'  # usually want to move pasted objects
        setSelection (obj._id for obj in objects)
      else
        ## Cache text content in case we want to paste it later; walking
        ## through all items during `tryAddImage` seems to clear text content.
        text = e.clipboardData.getData 'text/plain'
        obj =
          pts: [snapPoint board.relativePoint 0.25, 0.25]
        ## First check for image paste
        if image = await tryAddImage e.clipboardData.items, obj
          setSelection [image._id]
        ## On failure, paste text content as text object
        else if text
          selectTool 'text'
          undoStack.pushAndDo
            type: 'new'
            obj: obj =
              room: room.id
              page: room.page
              type: 'text'
              text: text
              pts: obj.pts
              color: currentColor.get()
              fontSize: currentFontSize.get()
          setSelection [obj._id]

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

## Cocreate doesn't perform great in combination with Meteor DevTools;
## prevent it from applying its hooks.
window.__devtools = true
