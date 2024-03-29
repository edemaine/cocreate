## Grid rendering and snapping

import dom from './lib/dom'
import {closer, transposeXY} from './lib/geom'
import {currentGridType, currentRoom} from './AppState'
import {BBox} from './BBox'
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
  if currentRoom()?.gridSnap.get()
    snapPointToGrid pt, currentRoom().gridHalfSnap.get()
  else
    pt

export snapPointToGrid = (pt, isHalf, gridType = currentGridType()) ->
  if isHalf
    half = 0.5
  else
    half = 1
  switch gridType
    when 'square'
      x: round pt.x, gridSize * half
      y: round pt.y, gridSize * half
    when 'triangle'
      triSnap = (pt, scale) ->
        r = Math.round pt.y / (triangleVerticalGridSize * scale)
        x:
          if r % 2 == 0
            round pt.x, gridSize * scale
          else
            (halfGridSize * scale) +
              round pt.x - (halfGridSize * scale), gridSize * scale
        y: r * (triangleVerticalGridSize * scale)
      rounded = triSnap pt, half
      if isHalf
        ## Check for closer match to the center of a triangle.
        ## These are on a hex grid, but also on a rotated/xy-flipped
        ## triangular grid of scale 1/sqrt(3), whose other points
        ## are in the already-searched grid so doesn't hurt to include.
        rounded = closer pt, rounded,
          transposeXY triSnap transposeXY(pt), 1/Math.sqrt 3
      rounded

export gridOffset = (dx, dy, gridType = currentGridType()) ->
  switch gridType
    when 'square'
      x: dx * gridSize
      y: dy * gridSize
    when 'triangle'
      x: (dx - (dy % 2) / 2) * gridSize
      y: dy * triangleVerticalGridSize

export class Grid
  constructor: (@page) ->
    @page.board.root.appendChild @grid = dom.create 'g', class: 'grid'
    @update()
  update: (bounds) ->
    @grid.innerHTML = ''
    board = @page.board
    bounds ?= BBox.fromExtremePoints(
      dom.svgPoint board.svg, board.clientBBox.left, board.clientBBox.top, @grid
      dom.svgPoint board.svg, board.clientBBox.right, board.clientBBox.bottom, @grid
    )
    visibleGridSize = gridSize
    if @page.board.transform.scale < 1/gridScaleDown
      visibleGridSize *= Math.round 1 / (gridScaleDown * @page.board.transform.scale)
    margin = gridSize
    switch @page.gridMode
      when 'square'
        for x in roundRange bounds.minX, bounds.maxX, visibleGridSize
          @grid.appendChild dom.create 'line',
            x1: x
            x2: x
            y1: bounds.minY - margin
            y2: bounds.maxY + margin
        for y in roundRange bounds.minY, bounds.maxY, visibleGridSize
          @grid.appendChild dom.create 'line',
            y1: y
            y2: y
            x1: bounds.minX - margin
            x2: bounds.maxX + margin
      when 'triangle'
        verticalGridSize = visibleGridSize * rt3/2
        ## Round an additional factor of two to fix parity of grid lines
        minY = roundDown bounds.minY, 2 * verticalGridSize
        maxY = roundUp bounds.maxY, 2 * verticalGridSize
        dx = (maxY - minY) / rt3
        for x in roundRange bounds.minX - dx, bounds.maxX, visibleGridSize
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
        for y in roundRange bounds.minY, bounds.maxY, verticalGridSize
          @grid.appendChild dom.create 'line',
            y1: y
            y2: y
            x1: bounds.minX - margin
            x2: bounds.maxX + margin
      #else
