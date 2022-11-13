import {undoStack} from './UndoStack'

export anchorRadius = 4
export anchorStroke = 2
#export anchorVisualRadius = anchorRadius + anchorStroke / 2
export anchorObjectTypes = new Set ['poly', 'rect', 'ellipse']

export anchorsOf = (obj) ->
  switch obj.type
    when 'poly'
      obj.pts
    when 'rect', 'ellipse'
      obj.pts.concat [
        x: obj.pts[0].x
        y: obj.pts[1].y
      ,
        x: obj.pts[1].x
        y: obj.pts[0].y
      ]
    else
      []

pointMove = (moved, index, coords) ->
  if moved[index].x == coords.x and moved[index].y == coords.y
    false
  else
    moved[index] =
      x: coords.x
      y: coords.y
    true

export anchorMove = (obj, moved, index, coords) ->
  if index > 1 and obj.type in ['rect', 'ellipse', 'image']
    if index == 2
      pointMove(moved, 0, {x: coords.x, y: moved[0].y}) or
      pointMove(moved, 1, {y: coords.y, x: moved[1].x})
    else if index == 3
      pointMove(moved, 1, {x: coords.x, y: moved[1].y}) or
      pointMove(moved, 0, {y: coords.y, x: moved[0].x})
    else
      console.error "Invalid anchor index #{index}"
  else if 0 <= index < obj.pts.length
    pointMove moved, index, coords
  else
    console.error "Out-of-bounds anchor index #{index}"

#export anchorIntersects = (point, anchor) ->
#  Math.abs(point.x - anchor.x) <= anchorVisualRadius and
#  Math.abs(point.y - anchor.y) <= anchorVisualRadius

export anchorFromEvent = (e, anchorSelection) ->
  ## Find topmost anchor below mouse pointer,
  ## preferring a selected one if selection is provided.
  ## Returns {elt, id, index, selected} where `elt` is the anchor DOM object,
  ## or undefined if no anchor was found.
  anchor = undefined
  for elt in document.elementsFromPoint e.clientX, e.clientY
    if elt.classList.contains 'anchor'
      {id, index} = decodeAnchor elt
      if not anchorSelection? or (selected = anchorSelection.has id, index)
        return {elt, id, index, selected}
      else
        anchor ?= {elt, id, index, selected}
  anchor if anchor?

export decodeAnchor = (elt) ->
  id: elt.dataset.obj
  index: parseInt elt.dataset.index, 10

export class AnchorSelection
  constructor: (@board) ->
    @selected = {}
  nonempty: ->
    for id of @selected  # eslint-disable-line coffee/no-unused-vars
      return true
    false
  has: (id, index) ->
    {id, index} = id if id.id?
    @selected[id]?[index]?
  hasId: (id) ->
    @selected[id]?
  indicesForId: (id) ->
    (parseInt index, 10 for index of @selected[id])
  add: (id, index) ->
    {id, index} = id if id.id?
    @selected[id] ?= {}
    @selected[id][index] = true
    @board.render?.anchors?[id]?[index]?.classList.add 'select'
  remove: (id, index) ->
    {id, index} = id if id.id?
    @board.render?.anchors?[id]?[index]?.classList.remove 'select'
    return unless @selected[id]?
    delete @selected[id][index]
    ## Check whether this id has any anchors still selected
    any = false
    for otherIndex of @selected[id]  # eslint-disable-line coffee/no-unused-vars
      any = true
      break
    delete @selected[id] unless any
  toggle: (id, index) ->
    if @has id, index
      @remove id, index
    else
      @add id, index
  ids: ->
    id for id of @selected
  objs: ->
    for id in @ids()
      obj = Objects.findOne id
      continue unless obj?
      obj
  clear: ->
    for id, indices of @selected
      for index of indices
        @board.render?.anchors?[id]?[index]?.classList.remove 'select'
    @selected = {}

  translate: ({x, y}) ->
    return if @board.readonly
    return unless x or y
    objs = @objs()
    return unless objs.length
    undoStack.pushAndDo
      type: 'multi'
      ops:
        for obj in objs
          before = pts: obj.pts
          after = pts: obj.pts[..]
          anchors = anchorsOf obj
          for index in @indicesForId obj._id
            anchorMove obj, after.pts, index,
              x: anchors[index].x + x
              y: anchors[index].y + y
          type: 'edit'
          id: obj._id
          before: before
          after: after
