## Dynamic Bounding Volume Tree, *not currently used* to accelerate
## selecting objects that intersect a query rectangle.

import dom from './lib/dom'

class DBVTNode
  constructor: ->

  @leaf: (id, bbox) ->
    node = new DBVTNode()
    node.left = null
    node.right = null
    node.parent = null
    node.id = id
    node.bbox = bbox
    node

  @internal: (left, right, parent) ->
    node = new DBVTNode()
    node.left = left
    node.right = right
    node.parent = parent
    left.parent = node
    right.parent = node
    node.id = null
    node.bbox = left.bbox.union right.bbox
    node

  isRoot: ->
    not @parent?

  isLeaf: ->
    not @left?

  # 0 if left child, 1 if right child. Assumes this node has a parent
  childIndex: ->
    if @ == @parent.left then 0 else 1

  # Gets the child at a specific index.
  child: (index) ->
    if index == 0 then @left else @right

  # Sets the child at a specific index.
  setChild: (index, node) ->
    if index == 0 then @left = node else @right = node

  # Assumes this node has a parent
  sibling: ->
    if @ == @parent.left then @parent.right else @parent.left

  # Returns the new root if the root changed.
  insert: (node) ->
    #if lrCost <= lnCost and lrCost <= rnCost
    if @isLeaf()
      if @parent?
        side = @childIndex()
      newNode = DBVTNode.internal @, node, @parent
      if newNode.parent?
        newNode.parent.setChild(side, newNode)

      if newNode.isRoot() 
        newNode
      else
        @parent.balance()
        null
    else
      # l = left child, r = right child, n = new node
      ln = @left.bbox.union node.bbox
      rn = @right.bbox.union node.bbox
      lnCost = ln.cost() ? Infinity
      rnCost = rn.cost() ? Infinity

      @bbox = @bbox.union node.bbox
      if lnCost <= rnCost
        @left.insert node
      else
        @right.insert node

  # Requires parent to exist.
  # Returns new root if the root changed.
  remove: ->
    sibling = @sibling()
    sibling.parent = @parent.parent
    if sibling.parent?
      sibling.parent.setChild(@parent.childIndex(), sibling)

      # Update BBoxs and balance
      sibling.parent.balance()
      null
    else
      sibling

  # Balance this node's parent so that the maximum BBox areas of its children is minimized.
  # Assumes the node has children.
  balance: ->
    if @parent?
      sibling = @sibling()
      # l = left child, r = right child, s = sibling.
      # Possibilities: switch child and sibling, or do nothing
      lr = @left.bbox.union @right.bbox
      ls = @left.bbox.union sibling.bbox
      rs = @right.bbox.union sibling.bbox

      lrCost = Math.max lr.cost(), sibling.bbox.cost()
      lsCost = Math.max ls.cost(), @right.bbox.cost()
      rsCost = Math.max rs.cost(), @left.bbox.cost()

      if lrCost <= lsCost and lrCost <= rsCost
        @bbox = lr
      else if lsCost <= rsCost
        @bbox = ls
        @parent.setChild(sibling.childIndex(), @right)
        @right.parent = @parent
        @right = sibling
        sibling.parent = @
      else
        @bbox = rs
        @parent.setChild(sibling.childIndex(), @left)
        @left.parent = @parent
        @left = sibling
        sibling.parent = @
      @parent.balance()
    else
      @bbox = @left.bbox.union @right.bbox

  # Returns ids of leaf nodes that the bbox intersects
  query: (bbox) ->
    if @bbox.intersects bbox
      if @id?
        yield @id
      else
        yield from @left.query bbox
        yield from @right.query bbox

  # Checks the integrity of the structure and logs integrity errors
  checkIntegrity: ->
    if @left? or @right?
      DBVT.assert @left? and @right?, "Node has exactly 1 child", @
      DBVT.assert @left.parent == @, "Node's left child doesn't point back to it", @
      DBVT.assert @right.parent == @, "Node's right child doesn't point back to it", @
      DBVT.assert not @id?, "Non-leaf node has id", @
      DBVT.assert ((@left.bbox.union @right.bbox).eq @bbox), "Node's BBox is not the union of child BBoxs", @
      @left.checkIntegrity()
      @right.checkIntegrity()
    else
      DBVT.assert @id?, "Leaf node has no id", @
  
  leaves: ->
    if @isLeaf()
      yield @
    else
      yield from @left.leaves()
      yield from @right.leaves()

  exportDebugSVG: (svgParent) ->
    rect = dom.create 'rect',
      'x': @bbox.minX
      'y': @bbox.minY
      'width': @bbox.maxX - @bbox.minX
      'height': @bbox.maxY - @bbox.minY
      'stroke': '#ff0000'
      'stroke-width': 1
      'fill': 'none', null, null, svgParent
    group = dom.create 'g'
    svgParent.appendChild rect
    svgParent.appendChild group

    @left?.exportDebugSVG group
    @right?.exportDebugSVG group

export class DBVT
  constructor: ->
    @root = null
    @nodesById = {}
    # TODO: Remove

  insert: (id, bbox) ->
    node = DBVTNode.leaf id, bbox.fattened(38)
    @nodesById[id] = node
    @root = (@root?.insert node) ? @root ? node
    # TODO: Remove

  move: (id, bbox) ->
    node = @nodesById[id]
    unless node.bbox.contains bbox
      @remove id
      @insert id, bbox

  remove: (id) ->
    node = @nodesById[id]
    if node.isRoot()
      @root = null
    else
      @root = node.remove() ? @root
    delete @nodesById[id]
    # TODO: Remove

  query: (bbox) ->
    if @root?
      yield from @root.query bbox

  @assert: (condition, print...) ->
    unless condition
      console.log "DBVT integrity fail", print...

  # Checks the integrity of the structure and logs integrity errors
  checkIntegrity: ->
    DBVT.assert not @root?.parent?, "Root has a parent", @root
    @root?.checkIntegrity()

    if @root?
      leavesArr = Array.from @root.leaves()
      leaves = Object.fromEntries ([leaf.id, leaf] for leaf in leavesArr)
      DBVT.assert leavesArr.length == (Object.keys leaves).length, "Duplicate leaf", leavesArr

      for _, leaf of leaves
        DBVT.assert @nodesById[leaf.id] == leaf, "Leaf id is recorded incorrectly", leaf, @nodesById

      for id, node of @nodesById
        DBVT.assert node.id == id, "Leaf node is recorded incorrectly", id, node
        DBVT.assert leaves[id]?, "Leaf node is not reachable from root", id, node, @
    else
      DBVT.assert (Object.keys @nodesById).length == 0, "Leaf cache should be empty", @

  exportDebugSVG: (svgParent) ->
    while svgParent.firstChild?
      svgParent.removeChild svgParent.firstChild
    @root?.exportDebugSVG svgParent
    svgParent
