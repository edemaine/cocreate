## Dynamic bounding volume tree, used to accelerate box queries
## when selecting objects that intersect a box.

import dom from './lib/dom'

export class Aabb
  constructor: (@min_x, @min_y, @max_x, @max_y) ->

  @from_rect: (rect) ->
    new Aabb rect.x, rect.y, rect.x + rect.width, rect.y + rect.height

  @from_obj: (obj, svg, svg_root, dom_map) ->
    ## Unfortunately, getBBox doesn't take the transform of the current node into account.
    ## So wrap it in a group and hope it doesn't break anything.
    elt = dom_map[obj._id]
    ext = dom.svgExtremes svg, elt, svg_root
    new Aabb ext.min.x, ext.min.y, ext.max.x, ext.max.y

  area: ->
    (@max_x - @min_x) * (@max_y - @min_y)

  intersects: (other) ->
    @min_x <= other.max_x && @max_x >= other.min_x && @min_y <= other.max_y && @max_y >= other.min_y

  contains: (other) ->
    @min_x <= other.min_x && @max_x >= other.max_x && @min_y <= other.min_y && @max_y >= other.max_y

  union: (other) ->
    new Aabb \
      (Math.min @min_x, other.min_x), (Math.min @min_y, other.min_y), \
      (Math.max @max_x, other.max_x), (Math.max @max_y, other.max_y),

  eq: (other) ->
    @min_x == other.min_x && @max_x == other.max_x && @min_y == other.min_y && @max_y == other.max_y

class DbvtNode
  constructor: ->

  @leaf: (id, aabb) ->
    node = new DbvtNode()
    node.children = [null, null]
    node.parent = null
    node.id = id
    node.aabb = aabb
    node

  @parent: (left, right, parent) ->
    node = new DbvtNode()
    node.children = [left, right]
    node.parent = parent
    left.parent = node
    right.parent = node
    node.id = null
    node.aabb = left.aabb.union right.aabb
    node

  is_root: ->
    !@parent?

  is_leaf: ->
    !@children[0]?

  # 0 if left child, 1 if right child. Assumes this node has a parent
  child_index: ->
    if @ == @parent.children[0] then 0 else 1

  # Assumes this node has a parent
  sibling: ->
    if @ == @parent.children[0] then @parent.children[1] else @parent.children[0]

  # Returns the new root if the root changed.
  insert: (node) ->
    # When inserting a node, we can insert it as a child of this node
    # or dig deeper. We need to find the cost of each.
    # l = left child, r = right child, n = new node
    lr = @aabb
    ln = @children[0]?.aabb.union node.aabb
    rn = @children[1]?.aabb.union node.aabb
    lr_cost = lr.area()
    ln_cost = ln?.area() ? Infinity
    rn_cost = rn?.area() ? Infinity

    if lr_cost <= ln_cost && lr_cost <= rn_cost
      if @parent?
        side = @child_index()
      new_node = DbvtNode.parent @, node, @parent
      if new_node.parent?
        new_node.parent.children[side] = new_node

      if new_node.is_root() 
        new_node
      else
        @parent.balance()
        null
    else
      @aabb = @aabb.union node.aabb
      if ln_cost <= rn_cost
        @children[0].insert node
      else
        @children[1].insert node

  # Requires parent to exist.
  # Returns new root if the root changed.
  remove: ->
    sibling = @sibling()
    sibling.parent = @parent.parent
    if sibling.parent?
      sibling.parent.children[@parent.child_index()] = sibling

      # Update AABBs and balance
      sibling.parent.balance()
      null
    else
      sibling

  # Balance this node's parent so that the maximum AABB areas of its children is minimized.
  # Assumes the node has children.
  balance: ->
    if @parent?
      sibling = @sibling()
      # l = left child, r = right child, s = sibling.
      # Possibilities: switch child and sibling, or do nothing
      lr = @children[0].aabb.union @children[1].aabb
      ls = @children[0].aabb.union sibling.aabb
      rs = @children[1].aabb.union sibling.aabb

      lr_cost = Math.max lr.area(), sibling.aabb.area()
      ls_cost = Math.max ls.area(), @children[1].aabb.area()
      rs_cost = Math.max rs.area(), @children[0].aabb.area()

      if lr_cost <= ls_cost && lr_cost <= rs_cost
        @aabb = lr
      else if ls_cost <= rs_cost
        @aabb = ls
        @parent.children[sibling.child_index()] = @children[1]
        @children[1].parent = @parent
        @children[1] = sibling
        sibling.parent = @
      else
        @aabb = rs
        @parent.children[sibling.child_index()] = @children[0]
        @children[0].parent = @parent
        @children[0] = sibling
        sibling.parent = @
      @parent.balance()
    else
      @aabb = @children[0].aabb.union @children[1].aabb

  # Returns ids of leaf nodes that the aabb intersects
  query: (aabb) ->
    if @aabb.intersects aabb
      if @id?
        yield @id
      else
        yield from @children[0].query aabb
        yield from @children[1].query aabb

  # Checks the integrity of the structure and logs integrity errors
  check_integrity: ->
    if @children[0]? || @children[1]?
      Dbvt.assert @children[0]? && @children[1]?, "Node has exactly 1 child", @
      Dbvt.assert @children[0].parent == @, "Node's left child doesn't point back to it", @
      Dbvt.assert @children[1].parent == @, "Node's right child doesn't point back to it", @
      Dbvt.assert !@id?, "Non-leaf node has id", @
      Dbvt.assert ((@children[0].aabb.union @children[1].aabb).eq @aabb), "Node's AABB is not the union of child AABBs", @
      @children[0].check_integrity()
      @children[1].check_integrity()
    else
      Dbvt.assert @id?, "Leaf node has no id", @
  
  leaves: ->
    if @is_leaf()
      yield @
    else
      yield from @children[0].leaves()
      yield from @children[1].leaves()

  export_debug_svg: (svg_parent) ->
    rect = dom.create 'rect',
      'x': @aabb.min_x
      'y': @aabb.min_y
      'width': @aabb.max_x - @aabb.min_x
      'height': @aabb.max_y - @aabb.min_y
      'stroke': '#ff0000'
      'stroke-width': 1
      'fill': 'none', null, null, svg_parent
    group = dom.create 'g'
    svg_parent.appendChild rect
    svg_parent.appendChild group

    @children[0]?.export_debug_svg group
    @children[1]?.export_debug_svg group

export class Dbvt
  constructor: ->
    @root = null
    @nodes_by_id = {}
    # TODO: Remove

  insert: (id, aabb) ->
    node = DbvtNode.leaf id, aabb
    @nodes_by_id[id] = node
    @root = (@root?.insert node) ? @root ? node
    # TODO: Remove

  remove: (id) ->
    node = @nodes_by_id[id]
    if node.is_root()
      @root = null
    else
      @root = node.remove() ? @root
    delete @nodes_by_id[id]
    # TODO: Remove
    
  query: (aabb) ->
    if @root?
      yield from @root.query aabb

  @assert: (condition, print...) ->
    if !condition
      console.log "DBVT integrity fail", print...

  # Checks the integrity of the structure and logs integrity errors
  check_integrity: ->
    Dbvt.assert !@root?.parent?, "Root has a parent", @root
    @root?.check_integrity()

    if @root?
      leaves_arr = Array.from @root.leaves()
      leaves = Object.fromEntries ([leaf.id, leaf] for leaf in leaves_arr)
      Dbvt.assert leaves_arr.length == (Object.keys leaves).length, "Duplicate leaf", leaves_arr

      for _, leaf of leaves
        Dbvt.assert @nodes_by_id[leaf.id] == leaf, "Leaf id is recorded incorrectly", leaf, @nodes_by_id

      for id, node of @nodes_by_id
        Dbvt.assert node.id == id, "Leaf node is recorded incorrectly", id, node
        Dbvt.assert leaves[id]?, "Leaf node is not reachable from root", id, node, @
    else
      Dbvt.assert (Object.keys @nodes_by_id).length == 0, "Leaf cache should be empty", @

  export_debug_svg: (svg_parent) ->
    while svg_parent.firstChild?
      svg_parent.removeChild svg_parent.firstChild
    @root?.export_debug_svg svg_parent
    svg_parent