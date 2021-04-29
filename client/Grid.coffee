## Grid rendering

import dom from './lib/dom'

export gridSize = 37.76

export gridDefault = true

## Scale down visibility of grid lines when zoomed out by more than this factor
gridScaleDown = 10

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
      when true
        range = (xy) ->
          [Math.floor(bounds.min[xy] / visibleGridSize) .. \
           Math.ceil bounds.max[xy] / visibleGridSize]
        for i in range 'x'
          x = i * visibleGridSize
          @grid.appendChild dom.create 'line',
            x1: x
            x2: x
            y1: bounds.min.y - margin
            y2: bounds.max.y + margin
        for j in range 'y'
          y = j * visibleGridSize
          @grid.appendChild dom.create 'line',
            y1: y
            y2: y
            x1: bounds.min.x - margin
            x2: bounds.max.x + margin
      #else
