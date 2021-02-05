## Grid rendering

import dom from './lib/dom'

export gridSize = 37.76

export gridDefault = true

export class Grid
  constructor: (@room) ->
    @room.board.root.appendChild @grid = dom.create 'g', class: 'grid'
    @update()
  update: (mode = @room.pageGrid, bounds) ->
    @grid.innerHTML = ''
    board = @room.board
    bounds ?=
      min: dom.svgPoint board.svg, board.bbox.left, board.bbox.top, @grid
      max: dom.svgPoint board.svg, board.bbox.right, board.bbox.bottom, @grid
    margin = gridSize
    switch mode
      when true
        ### eslint-disable no-unused-vars ###
        range = (xy) ->
          [Math.floor(bounds.min[xy] / gridSize) .. \
           Math.ceil bounds.max[xy] / gridSize]
        ### eslint-enable no-unused-vars ###
        for i in range 'x'
          x = i * gridSize
          @grid.appendChild dom.create 'line',
            x1: x
            x2: x
            y1: bounds.min.y - margin
            y2: bounds.max.y + margin
        for j in range 'y'
          y = j * gridSize
          @grid.appendChild dom.create 'line',
            y1: y
            y2: y
            x1: bounds.min.x - margin
            x2: bounds.max.x + margin
      #else
