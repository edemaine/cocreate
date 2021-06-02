export defaultGrid = true
export defaultGridType = 'square'

export validGridType = (gridType) ->
  typeof gridType == 'string' and
  gridType in ['square', 'triangle']
