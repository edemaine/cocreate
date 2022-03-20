import {BBox} from './BBox'

intersectsSpecific = 
  pen: (query, obj, bbox) ->
    # Lines first.
    for i in [0...obj.pts.length - 1]
      pt0 = obj.pts[i]
      pt1 = obj.pts[i + 1]
      if pt0.x == pt1.x and pt0.y == pt1.y
        continue

      # Transform everything so the line is centered at the origin.
      center = {x: (pt1.x + pt0.x) / 2, y: (pt1.y + pt0.y) / 2}
      pt = {x: pt0.x - center.x, y: pt0.y - center.y}
      testPt = query.center()
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

      # Test point against Minkowski sum of the rectangle and the query.
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
          x: testPt.x + fx * query.width() / 2
          y: testPt.y + fy * query.height() / 2
        # Counterclockwise check
        if (p1.x - p0.x) * (p2.y - p0.y) - (p1.y - p0.y) * (p2.x - p0.x) > 0
          inHalfPlanes = false
          break

      # Test horizontal and vertical half-planes that come from the query
      # when factored into the Minkowski sum.
      if inHalfPlanes and
         testPt.x + query.width() / 2 >= pt0.x and
         testPt.y - query.height() / 2 <= pt1.y and
         testPt.x - query.width() / 2 <= -pt0.x and
         testPt.y + query.height() / 2 >= -pt1.y
        return true

    # Circles next.
    for pt in obj.pts
      return true if intersectsSpecific.rect query, {width: obj.width}, \
        (new BBox pt.x, pt.y, pt.x, pt.y).fattened (obj.width / 2)

    false

  poly: (query, obj, bbox) ->
    intersectsSpecific.pen query, obj

  rect: (query, obj, bbox) ->
    # Minkowski sum to make outer test simpler
    fattened = bbox.fattenedXY (query.width() - obj.width) / 2,
                               (query.height() - obj.width) / 2
    testPt = query.center()

    if fattened.containsPoint testPt
      # Inside. Take fill or lack of fill into account.
      obj.fill? or not (bbox.fattened -obj.width).contains query
    else
      # Outside. Take roundedness into account.
      testPt.x -= bbox.center().x
      testPt.y -= bbox.center().y
      testPt.x = Math.max 0, (Math.abs testPt.x) - fattened.width() / 2
      testPt.y = Math.max 0, (Math.abs testPt.y) - fattened.height() / 2
      testPt.x * testPt.x + testPt.y * testPt.y <= (obj.width / 2) * (obj.width / 2)

  ellipse: (query, obj, bbox) ->
    testPt = query.center()

    # Transform everything so the ellipse is centered at the origin.
    testPt.x -= bbox.center().x
    testPt.y -= bbox.center().y

    # Test outer ellipse.
    collapsed =
      x: Math.max 0, (Math.abs testPt.x) - query.width() / 2
      y: Math.max 0, (Math.abs testPt.y) - query.height() / 2
    if collapsed.x * collapsed.x /
         ((bbox.width() / 2) * (bbox.width() / 2)) +
       collapsed.y * collapsed.y /
         ((bbox.height() / 2) * (bbox.height() / 2)) > 1
      return false

    unless obj.fill?
      # Test inner ellipse using Minkowski difference,
      # which in this case is the intersection of four ellipses.
      for [fx, fy] in [[1, -1], [-1, -1], [-1, 1], [1, 1]]
        pt = {x: testPt.x + fx * query.width() / 2, y: testPt.y + fy * query.height() / 2}
        width = bbox.width() / 2 - obj.width
        height = bbox.height() / 2 - obj.width
        if pt.x * pt.x / (width * width) + pt.y * pt.y / (height * height) >= 1
          return true
      return false

    true

  text: (query, obj, bbox) ->
    query.intersects obj.bbox

  image: (query, obj, bbox) ->
    query.intersects obj.bbox

export intersects = (query, obj, bbox) ->
  intersectsSpecific[obj.type] query, obj, bbox
