## Grid rendering and snapping

import dom from './lib/dom'
import {currentGridType, currentRoom} from './AppState'

export {defaultGrid, defaultGridType} from '/lib/grid'

export gridSize = 37.76
rt3 = Math.sqrt 3
triangleVerticalGridSize = gridSize * rt3/2
halfGridSize = gridSize/2

## Scale down visibility of grid lines when zoomed out by more than this factor
gridScaleDown = 10

round = (x, gap) -> gap * Math.round x / gap
roundDown = (x, gap) -> gap * Math.floor x / gap
roundUp = (x, gap) -> gap * Math.ceil x / gap
roundRange = (min, max, gap) ->
  for i in [Math.floor(min / gap) .. Math.ceil(max / gap)]
    i * gap

export maybeSnapPointToGrid = (pt) ->
  if currentRoom.get()?.gridSnap.get()
    snapPointToGrid pt
  else
    pt

export snapPointToGrid = (pt, gridType = currentGridType()) ->
  switch gridType
    when 'square'
      pt.x = round pt.x, gridSize
      pt.y = round pt.y, gridSize
    when 'triangle'
      #pt.y = round pt.y, gridSize * hrt3
      r = Math.round pt.y / triangleVerticalGridSize
      pt.y = r * triangleVerticalGridSize
      if r % 2 == 0
        pt.x = round pt.x, gridSize
      else
        pt.x = halfGridSize + round pt.x - halfGridSize, gridSize
  pt

export gridUnitOffset = (gridType = currentGridType()) ->
  switch gridType
    when 'square'
      x: gridSize
      y: gridSize
    when 'triangle'
      x: gridSize / 2
      y: triangleVerticalGridSize

export class Grid
  constructor: (@page) ->
    @page.board.root.appendChild @grid = dom.create 'g', class: 'grid'
    @update()
  update: (bounds) ->
    @grid.innerHTML = ''
    board = @page.board
    bounds ?=
      min: dom.svgPoint board.svg, board.bbox.left, board.bbox.top, @grid
      max: dom.svgPoint board.svg, board.bbox.right, board.bbox.bottom, @grid
    visibleGridSize = gridSize
    if @page.board.transform.scale < 1/gridScaleDown
      visibleGridSize *= Math.round 1 / (gridScaleDown * @page.board.transform.scale)
    margin = gridSize
    switch @page.gridMode
      when 'square'
        for x in roundRange bounds.min.x, bounds.max.x, visibleGridSize
          @grid.appendChild dom.create 'line',
            x1: x
            x2: x
            y1: bounds.min.y - margin
            y2: bounds.max.y + margin
        for y in roundRange bounds.min.y, bounds.max.y, visibleGridSize
          @grid.appendChild dom.create 'line',
            y1: y
            y2: y
            x1: bounds.min.x - margin
            x2: bounds.max.x + margin
      when 'triangle'
        verticalGridSize = visibleGridSize * rt3/2
        ## Round an additional factor of two to fix parity of grid lines
        minY = roundDown bounds.min.y, 2 * verticalGridSize
        maxY = roundUp bounds.max.y, 2 * verticalGridSize
        dx = (maxY - minY) / rt3
        for x in roundRange bounds.min.x - dx, bounds.max.x, visibleGridSize
          @grid.appendChild dom.create 'line',
            x1: x - margin / rt3
            x2: x + dx + margin / rt3
            y1: minY - margin
            y2: maxY + margin
          @grid.appendChild dom.create 'line',
            x1: x + dx + margin / rt3
            x2: x - margin / rt3
            y1: minY - margin
            y2: maxY + margin
        for y in roundRange bounds.min.y, bounds.max.y, verticalGridSize
          @grid.appendChild dom.create 'line',
            y1: y
            y2: y
            x1: bounds.min.x - margin
            x2: bounds.max.x + margin
      #else
