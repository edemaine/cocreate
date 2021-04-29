## Dynamic bounding volume tree, used to accelerate box queries
## when selecting objects that intersect a box.

import dom from './lib/dom'

export class Aabb
  constructor: (@minX, @minY, @maxX, @maxY) ->

  @fromRect: (rect) ->
    new Aabb rect.x, rect.y, rect.x + rect.width, rect.y + rect.height

  @fromObj: (obj, svg, svgRoot, objMap) ->
    elt = objMap[obj._id]
    ext = dom.svgExtremes svg, elt, svgRoot
    new Aabb ext.min.x, ext.min.y, ext.max.x, ext.max.y

  center: ->
    x: (@maxX + @minX) / 2
    y: (@maxY + @minY) / 2

  width: -> @maxX - @minX

  height: -> @maxY - @minY

  ## Adds fat to the AABB to allow for constant-time small changes to the object's position
  fattened: (fat) -> new Aabb (@minX - fat), (@minY - fat), (@maxX + fat), (@maxY + fat)

  ## Adds fat unevenly to the AABB to allow for constant-time small changes to the object's position
  fattenedXY: (fatX, fatY) -> new Aabb (@minX - fatX), (@minY - fatY), (@maxX + fatX), (@maxY + fatY)

  area: -> @width() * @height()

  perimeter: -> 2 * (@width() + @height())

  cost: -> @perimeter()

  intersects: (other) ->
    @minX <= other.maxX && @maxX >= other.minX && @minY <= other.maxY && @maxY >= other.minY

  contains: (other) ->
    @minX <= other.minX && @maxX >= other.maxX && @minY <= other.minY && @maxY >= other.maxY

  # Point must have an x field and a y field
  containsPoint: (pt) ->
    @minX <= pt.x && @maxX >= pt.x && @minY <= pt.y && @maxY >= pt.y

  union: (other) ->
    new Aabb \
      (Math.min @minX, other.minX), (Math.min @minY, other.minY), \
      (Math.max @maxX, other.maxX), (Math.max @maxY, other.maxY),

  eq: (other) ->
    @minX == other.minX && @maxX == other.maxX && @minY == other.minY && @maxY == other.maxY

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

  isRoot: ->
    !@parent?

  isLeaf: ->
    !@children[0]?

  # 0 if left child, 1 if right child. Assumes this node has a parent
  childIndex: ->
    if @ == @parent.children[0] then 0 else 1

  # Assumes this node has a parent
  sibling: ->
    if @ == @parent.children[0] then @parent.children[1] else @parent.children[0]

  # Returns the new root if the root changed.
  insert: (node) ->
    #if lrCost <= lnCost && lrCost <= rnCost
    if @isLeaf()
      if @parent?
        side = @childIndex()
      newNode = DbvtNode.parent @, node, @parent
      if newNode.parent?
        newNode.parent.children[side] = newNode

      if newNode.isRoot() 
        newNode
      else
        @parent.balance()
        null
    else
      # l = left child, r = right child, n = new node
      ln = @children[0].aabb.union node.aabb
      rn = @children[1].aabb.union node.aabb
      lnCost = ln.cost() ? Infinity
      rnCost = rn.cost() ? Infinity

      @aabb = @aabb.union node.aabb
      if lnCost <= rnCost
        @children[0].insert node
      else
        @children[1].insert node

  # Requires parent to exist.
  # Returns new root if the root changed.
  remove: ->
    sibling = @sibling()
    sibling.parent = @parent.parent
    if sibling.parent?
      sibling.parent.children[@parent.childIndex()] = sibling

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

      lrCost = Math.max lr.cost(), sibling.aabb.cost()
      lsCost = Math.max ls.cost(), @children[1].aabb.cost()
      rsCost = Math.max rs.cost(), @children[0].aabb.cost()

      if lrCost <= lsCost && lrCost <= rsCost
        @aabb = lr
      else if lsCost <= rsCost
        @aabb = ls
        @parent.children[sibling.childIndex()] = @children[1]
        @children[1].parent = @parent
        @children[1] = sibling
        sibling.parent = @
      else
        @aabb = rs
        @parent.children[sibling.childIndex()] = @children[0]
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
  checkIntegrity: ->
    if @children[0]? || @children[1]?
      Dbvt.assert @children[0]? && @children[1]?, "Node has exactly 1 child", @
      Dbvt.assert @children[0].parent == @, "Node's left child doesn't point back to it", @
      Dbvt.assert @children[1].parent == @, "Node's right child doesn't point back to it", @
      Dbvt.assert !@id?, "Non-leaf node has id", @
      Dbvt.assert ((@children[0].aabb.union @children[1].aabb).eq @aabb), "Node's AABB is not the union of child AABBs", @
      @children[0].checkIntegrity()
      @children[1].checkIntegrity()
    else
      Dbvt.assert @id?, "Leaf node has no id", @
  
  leaves: ->
    if @isLeaf()
      yield @
    else
      yield from @children[0].leaves()
      yield from @children[1].leaves()

  exportDebugSVG: (svgParent) ->
    rect = dom.create 'rect',
      'x': @aabb.minX
      'y': @aabb.minY
      'width': @aabb.maxX - @aabb.minX
      'height': @aabb.maxY - @aabb.minY
      'stroke': '#ff0000'
      'stroke-width': 1
      'fill': 'none', null, null, svgParent
    group = dom.create 'g'
    svgParent.appendChild rect
    svgParent.appendChild group

    @children[0]?.exportDebugSVG group
    @children[1]?.exportDebugSVG group

export class Dbvt
  constructor: ->
    @root = null
    @nodesById = {}
    # TODO: Remove

  insert: (id, aabb) ->
    node = DbvtNode.leaf id, aabb.fattened(38)
    @nodesById[id] = node
    @root = (@root?.insert node) ? @root ? node
    # TODO: Remove

  move: (id, aabb) ->
    node = @nodesById[id]
    if !node.aabb.contains aabb
      @remove id
      @insert id, aabb

  remove: (id) ->
    node = @nodesById[id]
    if node.isRoot()
      @root = null
    else
      @root = node.remove() ? @root
    delete @nodesById[id]
    # TODO: Remove
    
  query: (aabb) ->
    if @root?
      yield from @root.query aabb

  @assert: (condition, print...) ->
    if !condition
      console.log "DBVT integrity fail", print...

  # Checks the integrity of the structure and logs integrity errors
  checkIntegrity: ->
    Dbvt.assert !@root?.parent?, "Root has a parent", @root
    @root?.checkIntegrity()

    if @root?
      leavesArr = Array.from @root.leaves()
      leaves = Object.fromEntries ([leaf.id, leaf] for leaf in leavesArr)
      Dbvt.assert leavesArr.length == (Object.keys leaves).length, "Duplicate leaf", leavesArr

      for _, leaf of leaves
        Dbvt.assert @nodesById[leaf.id] == leaf, "Leaf id is recorded incorrectly", leaf, @nodesById

      for id, node of @nodesById
        Dbvt.assert node.id == id, "Leaf node is recorded incorrectly", id, node
        Dbvt.assert leaves[id]?, "Leaf node is not reachable from root", id, node, @
    else
      Dbvt.assert (Object.keys @nodesById).length == 0, "Leaf cache should be empty", @

  exportDebugSVG: (svgParent) ->
    while svgParent.firstChild?
      svgParent.removeChild svgParent.firstChild
    @root?.exportDebugSVG svgParent
    svgParent