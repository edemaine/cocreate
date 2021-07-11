## Dynamic bounding volume tree, used to accelerate box queries
## when selecting objects that intersect a box.

import dom from './lib/dom'

export class Aabb
  constructor: (@minX, @minY, @maxX, @maxY) ->

  @fromPoint: (pt) ->
    new Aabb pt.x, pt.y, pt.x, pt.y

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
    @minX <= other.maxX and @maxX >= other.minX and @minY <= other.maxY and @maxY >= other.minY

  contains: (other) ->
    @minX <= other.minX and @maxX >= other.maxX and @minY <= other.minY and @maxY >= other.maxY

  # Point must have an x field and a y field
  containsPoint: (pt) ->
    @minX <= pt.x and @maxX >= pt.x and @minY <= pt.y and @maxY >= pt.y

  union: (other) ->
    new Aabb \
      (Math.min @minX, other.minX), (Math.min @minY, other.minY), \
      (Math.max @maxX, other.maxX), (Math.max @maxY, other.maxY),

  eq: (other) ->
    @minX == other.minX and @maxX == other.maxX and @minY == other.minY and @maxY == other.maxY

class DbvtNode
  constructor: ->

  @leaf: (id, aabb) ->
    node = new DbvtNode()
    node.left = null
    node.right = null
    node.parent = null
    node.id = id
    node.aabb = aabb
    node

  @internal: (left, right, parent) ->
    node = new DbvtNode()
    node.left = left
    node.right = right
    node.parent = parent
    left.parent = node
    right.parent = node
    node.id = null
    node.aabb = left.aabb.union right.aabb
    node

  isRoot: ->
    !@parent?

  isLeaf: ->
    !@left?

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
      newNode = DbvtNode.internal @, node, @parent
      if newNode.parent?
        newNode.parent.setChild(side, newNode)

      if newNode.isRoot() 
        newNode
      else
        @parent.balance()
        null
    else
      # l = left child, r = right child, n = new node
      ln = @left.aabb.union node.aabb
      rn = @right.aabb.union node.aabb
      lnCost = ln.cost() ? Infinity
      rnCost = rn.cost() ? Infinity

      @aabb = @aabb.union node.aabb
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
      lr = @left.aabb.union @right.aabb
      ls = @left.aabb.union sibling.aabb
      rs = @right.aabb.union sibling.aabb

      lrCost = Math.max lr.cost(), sibling.aabb.cost()
      lsCost = Math.max ls.cost(), @right.aabb.cost()
      rsCost = Math.max rs.cost(), @left.aabb.cost()

      if lrCost <= lsCost and lrCost <= rsCost
        @aabb = lr
      else if lsCost <= rsCost
        @aabb = ls
        @parent.setChild(sibling.childIndex(), @right)
        @right.parent = @parent
        @right = sibling
        sibling.parent = @
      else
        @aabb = rs
        @parent.setChild(sibling.childIndex(), @left)
        @left.parent = @parent
        @left = sibling
        sibling.parent = @
      @parent.balance()
    else
      @aabb = @left.aabb.union @right.aabb

  # Returns ids of leaf nodes that the aabb intersects
  query: (aabb) ->
    if @aabb.intersects aabb
      if @id?
        yield @id
      else
        yield from @left.query aabb
        yield from @right.query aabb

  # Checks the integrity of the structure and logs integrity errors
  checkIntegrity: ->
    if @left? or @right?
      Dbvt.assert @left? and @right?, "Node has exactly 1 child", @
      Dbvt.assert @left.parent == @, "Node's left child doesn't point back to it", @
      Dbvt.assert @right.parent == @, "Node's right child doesn't point back to it", @
      Dbvt.assert !@id?, "Non-leaf node has id", @
      Dbvt.assert ((@left.aabb.union @right.aabb).eq @aabb), "Node's AABB is not the union of child AABBs", @
      @left.checkIntegrity()
      @right.checkIntegrity()
    else
      Dbvt.assert @id?, "Leaf node has no id", @
  
  leaves: ->
    if @isLeaf()
      yield @
    else
      yield from @left.leaves()
      yield from @right.leaves()

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

    @left?.exportDebugSVG group
    @right?.exportDebugSVG group

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