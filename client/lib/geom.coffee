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
