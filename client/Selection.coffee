## Highlighter class is for hover highlighting objects.
## Selection class is for maintaining and highlighted set of selected objects
## (which often come from Highlighter).

import {undoStack} from './UndoStack'
import {gridSize} from './Grid'
import {selectColor, selectFill, selectFillOff} from './tools/color'
import {selectWidth} from './tools/width'
import {selectFontSize} from './tools/font'
import {pointers} from './tools/modes'
import dom from './lib/dom'

export class Highlighter
  constructor: (@board, @type) ->
    @target = null       # <g/polyline/rect/ellipse/text>
    @highlighted = null  # <g/polyline/rect/ellipse/text class="highlight">
    @id = null           # highlighted object ID
  eventTop: (e) ->
    ## Pen and touch devices don't always seem to set `e.target` correctly;
    ## use `document.elementFromPoint` instead.
    #target = e.target
    #if target.tagName.toLowerCase() == 'svg'
    @findGroup document.elementFromPoint e.clientX, e.clientY
  eventCoalescedTop: (e) ->
    ## Find first event in the coalesced sequence that hits an object
    for c in e.getCoalescedEvents?() ? [e]
      if top = @eventTop c
        return top
    undefined
  eventAll: (e) ->
    for elt in document.elementsFromPoint e.clientX, e.clientY
      elt = @findGroup elt
      continue unless elt?
      elt
  eventSelected: (e, selection) ->
    return [] unless selection?
    target for target in @eventAll e when selection.has target.dataset.id
  findGroup: (target) ->
    while target? and not target.dataset?.id?
      return if target.classList?.contains 'board'
      target = target.parentNode
    return unless target?
    #return if target == @highlighted
    ## Shouldn't get pointer events on highlighted or selected overlays thanks
    ## to `pointer-events: none`, but check for them just in case:
    for elt in [target, target.parentNode]
      return if elt?.getAttribute('class') in ['highlight', 'selected']
    ## Check for specific match type
    if @type?
      return unless Objects.findOne(target.dataset.id)?.type == @type
    target
  highlight: (target) ->
    ## `target` should be the result of `findGroup` (or `eventTop`/`eventall`),
    ## so satisfies all above conditions.
    @clear()
    @target = target
    @id = target.dataset.id
    @highlighted ?= dom.create 'g', class: 'highlight'
    @board.root.appendChild @highlighted  # ensure on top
    doubler = (match, left, number, right) -> "#{left}#{2 * number}#{right}"
    html = target.outerHTML
    #.replace /\bdata-id=["'][^'"]*["']/g, ''
    .replace /(\bstroke-width=["'])([\d.]+)(["'])/g, doubler
    .replace /(\br=["'])([\d.]+)(["'])/g, doubler
    .replace /<image\b/g, '<image filter="url(#selectFilter)"'
    if /<text\b/.test html
      width = 1.5 # for text
      html = html.replace /\bfill=(["'][^"']+["'])/g, (match, fill) ->
        out = "#{match} stroke=#{fill} stroke-width=\"#{width}\""
        width = 100 # for LaTeX SVGs
        out
      .replace /<svg\b/, '$& overflow="visible"'
    @highlighted.innerHTML = html
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
      @highlighted.remove()
      @target = @highlighted = @id = null

export highlighterClear = ->
  for key, highlighter of pointers
    if highlighter instanceof Highlighter
      highlighter.clear()
      highlighter.selector?.remove()

export class Selection
  constructor: (@board) ->
    @selected = {}  # mapping from object ID to .selected DOM element
    @rehighlighter = new Highlighter @board  # used in redraw()
  add: (highlighter) ->
    id = highlighter.id
    return unless id?
    @selected[id] = highlighter.select()
    @outline()
  addId: (id) ->
    if target = @board.svg.querySelector \
         """svg > g > [data-id="#{CSS.escape id}"]"""
      @rehighlighter.highlight target
      @selected[id] = @rehighlighter.select()
      @outline()
    else
      ## Add an object to the selection before it's been rendered
      ## (triggering redraw when it gets rendered).
      @selected[id] = true
  redraw: (id, target) ->
    unless @selected[id] == true  # added via `addId`
      @selected[id].remove()
    @rehighlighter.highlight target
    @selected[id] = @rehighlighter.select()
    @outline()
  remove: (id) ->
    unless @selected[id] == true  # added via `addId`
      @selected[id].remove()
    delete @selected[id]
    @outline()
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
  json: ->
    JSON.stringify(
      if @board.objects?
        for id in @ids() when id of @board.objects
          @board.objects[id]
      else
        Objects.find
          _id: $in: @ids()
        .fetch()
    )
  delete: ->
    return if @board.readonly
    return unless @nonempty()
    ## The following is similar to eraser.up:
    undoStack.pushAndDo
      type: 'multi'
      ops:
        for id in @ids()
          type: 'del'
          obj: Objects.findOne id
    ## Clear any highlights in addition to clearing selection
    @clear()
    highlighterClear()
  edit: (attrib, value) ->
    return if @board.readonly
    objs =
      for id in @ids()
        obj = Objects.findOne id
        continue unless obj?
        switch attrib
          when 'width'
            continue unless obj.type in ['pen', 'poly', 'rect', 'ellipse']
          when 'fill'
            continue unless obj.type in ['rect', 'ellipse']
          when 'color'
            continue unless obj.type in ['pen', 'poly', 'rect', 'ellipse', 'text']
        obj
    return unless objs.length
    undoStack.pushAndDo
      type: 'multi'
      ops:
        for obj in objs
          #unless obj?[attrib]
          #  console.warn "Object #{id} has no #{attrib} attribute"
          #  continue
          type: 'edit'
          id: obj._id
          before: "#{attrib}": obj[attrib] ? null
          after: "#{attrib}": value
  duplicate: ->
    return if @board.readonly
    oldIds = @ids()
    newObjs =
      for id in oldIds
        obj = Objects.findOne id
        delete obj._id
        delete obj.updated
        delete obj.created
        obj.tx ?= 0
        obj.ty ?= 0
        obj.tx += gridSize
        obj.ty += gridSize
        obj._id = Meteor.apply 'objectNew', [obj], returnStubValue: true
        obj
    undoStack.push
      type: 'multi'
      ops:
        for obj in newObjs
          type: 'new'
          obj: obj
      selection: oldIds
    @clear()
    @addId obj._id for obj in newObjs
  outline: ->
    if @nonempty()
      @board.root.appendChild @rect ?= dom.create 'rect',
        class: 'outline'
      dom.attr @rect, dom.pointsToRect dom.unionSvgExtremes @board.svg,
        for id, elt of @selected
          continue if elt == true  # added via `addId`
          elt
      , @board.root
    else
      @rect?.remove()
      @rect = null
  setAttributes: ->
    ## Set user's attributes to match selected objects, if they're all same.
    return unless @nonempty()
    objects = (Objects.findOne id for id in @ids())
    for object in objects
      return unless object?  # not sure what to do if some object is missing
    uniformAttribute = (key, nullWild = true) ->
      values = (object[key] for object in objects)
      example = (value for value in values when value?)[0]
      for value in values
        ## Special null value represents "not uniform" (or "all null"),
        ## whereas if all values are undefined, we return undefined.
        return null unless value == example or (nullWild and not value?)
      example
    if (color = uniformAttribute 'color')?  # uniform draw color
      selectColor color, true, true
    if (fill = uniformAttribute 'fill', false)?  # uniform actual fill color
      selectFill fill, true
    if fill == undefined  # uniform no fill
      selectFillOff()
    if (width = uniformAttribute 'width')?  # uniform line width
      selectWidth width, true, true
    if (fontSize = uniformAttribute 'fontSize')?  # uniform font size
      selectFontSize fontSize, true, true
