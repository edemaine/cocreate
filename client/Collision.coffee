import {AABB} from './DBVT'

intersectsSpecific = 
  pen: (aabb, obj) ->
    # Lines first.
    for i in [0...obj.pts.length - 1]
      pt0 = obj.pts[i]
      pt1 = obj.pts[i + 1]
      if pt0.x == pt1.x and pt0.y == pt1.y
        continue

      # Transform everything so the line is centered at the origin.
      center = {x: (pt1.x + pt0.x) / 2, y: (pt1.y + pt0.y) / 2}
      pt = {x: pt0.x - center.x, y: pt0.y - center.y}
      testPt = aabb.center()
      testPt = {x: testPt.x - center.x, y: testPt.y - center.y}

      # Fatten line into rectangle consisting of points
      # pt0 -> pt1 -> -pt0 -> -pt1 in counterclockwise order.
      mag = Math.sqrt pt.x * pt.x + pt.y * pt.y
      perp = {x: pt.y / mag * obj.width / 2, y: -pt.x / mag * obj.width / 2}
      pt0 = {x: pt.x - perp.x, y: pt.y - perp.y}
      pt1 = {x: pt.x + perp.x, y: pt.y + perp.y}

      # Cycle points until pt0->pt1 goes in the +x and +y direction.
      while pt0.x > pt1.x or pt0.y > pt1.y
        [pt0, pt1] = [pt1, {x: -pt0.x, y: -pt0.y}]

      # For want of a vector library
      pt2 = {x: -pt0.x, y: -pt0.y}
      pt3 = {x: -pt1.x, y: -pt1.y}

      # Test point against Minkowski sum of the rectangle and the aabb.
      # It's convex, so do intersection of half-planes.
      inHalfPlanes = true
      for [p0, p1, fx, fy] in [
        [pt0, pt1, 1, -1],
        [pt1, pt2, -1, -1],
        [pt2, pt3, -1, 1],
        [pt3, pt0, 1, 1],
      ]
        # Test diagonal half-plane extended from rectangle edge.
        p2 =
          x: testPt.x + fx * aabb.width() / 2
          y: testPt.y + fy * aabb.height() / 2
        # Counterclockwise check
        if (p1.x - p0.x) * (p2.y - p0.y) - (p1.y - p0.y) * (p2.x - p0.x) > 0
          inHalfPlanes = false
          break

      # Test horizontal and vertical half-planes that come from the aabb
      # when factored into the Minkowski sum.
      if inHalfPlanes and
         testPt.x + aabb.width() / 2 >= pt0.x and
         testPt.y - aabb.height() / 2 <= pt1.y and
         testPt.x - aabb.width() / 2 <= -pt0.x and
         testPt.y + aabb.height() / 2 >= -pt1.y
        return true

    # Circles next.
    for pt in obj.pts
      if intersectsSpecific.rect aabb,
           width: obj.width
           aabb: (new AABB pt.x, pt.y, pt.x, pt.y).fattened (obj.width / 2)
        return true

    false

  poly: (aabb, obj) ->
    intersectsSpecific.pen aabb, obj

  rect: (aabb, obj) ->
    # Minkowski sum to make outer test simpler
    fattened = obj.aabb.fattenedXY (aabb.width() - obj.width) / 2,
                                   (aabb.height() - obj.width) / 2
    testPt = aabb.center()

    if fattened.containsPoint testPt
      # Inside. Take fill or lack of fill into account.
      obj.fill? or not (obj.aabb.fattened -obj.width).contains aabb
    else
      # Outside. Take roundedness into account.
      testPt.x -= obj.aabb.center().x
      testPt.y -= obj.aabb.center().y
      testPt.x = Math.max 0, (Math.abs testPt.x) - fattened.width() / 2
      testPt.y = Math.max 0, (Math.abs testPt.y) - fattened.height() / 2
      testPt.x * testPt.x + testPt.y * testPt.y <= (obj.width / 2) * (obj.width / 2)

  ellipse: (aabb, obj) ->
    testPt = aabb.center()

    # Transform everything so the ellipse is centered at the origin.
    testPt.x -= obj.aabb.center().x
    testPt.y -= obj.aabb.center().y

    # Test outer ellipse.
    collapsed =
      x: Math.max 0, (Math.abs testPt.x) - aabb.width() / 2
      y: Math.max 0, (Math.abs testPt.y) - aabb.height() / 2
    if collapsed.x * collapsed.x /
         ((obj.aabb.width() / 2) * (obj.aabb.width() / 2)) +
       collapsed.y * collapsed.y /
         ((obj.aabb.height() / 2) * (obj.aabb.height() / 2)) > 1
      return false

    unless obj.fill?
      # Test inner ellipse using Minkowski difference,
      # which in this case is the intersection of four ellipses.
      for [fx, fy] in [[1, -1], [-1, -1], [-1, 1], [1, 1]]
        pt = {x: testPt.x + fx * aabb.width() / 2, y: testPt.y + fy * aabb.height() / 2}
        width = obj.aabb.width() / 2 - obj.width
        height = obj.aabb.height() / 2 - obj.width
        if pt.x * pt.x / (width * width) + pt.y * pt.y / (height * height) >= 1
          return true
      return false

    true

  text: (aabb, obj) ->
    aabb.intersects obj.aabb

  image: (aabb, obj) ->
    aabb.intersects obj.aabb

export intersects = (aabb, obj) ->
  intersectsSpecific[obj.type] aabb, obj
