export average = (values) ->
  sum = 0
  for value in values
    sum += value
  sum / values.length

export centroid = (points) ->
  x = y = 0
  for point in points
    x += point.x
    y += point.y
  x /= points.length
  y /= points.length
  {x, y}

export distance = (p, q) ->
  dx = p.x - q.x
  dy = p.y - q.y
  Math.sqrt dx * dx + dy * dy

export distanceSquared = (p, q) ->
  dx = p.x - q.x
  dy = p.y - q.y
  dx * dx + dy * dy

export distanceThreshold = (p, q, t) ->
  t * t <= distanceSquared p, q

export closer = (goal, p, q) ->
  ## Return p or q, whichever is closer to goal
  if distanceSquared(p, goal) > distanceSquared(q, goal)
    q
  else
    p

export transposeXY = (pt) ->
  x: pt.y
  y: pt.x
