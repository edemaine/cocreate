SVGNS = 'http://www.w3.org/2000/svg'

board = null  # set to svg#board element
width = 5

pointerEvents = ->
  pointers = {}
  makeDot = (e) ->
    #pressureWidth = (0.5 + e.pressure) * width
    pressureWidth = 2 * e.pressure * width
    #pressureWidth = (2 * e.pressure) ** 3 * width
    if pointers[e.pointerId]
      line = document.createElementNS SVGNS, 'line'
      line.setAttribute 'x1', pointers[e.pointerId].getAttribute 'cx'
      line.setAttribute 'y1', pointers[e.pointerId].getAttribute 'cy'
      line.setAttribute 'x2', e.clientX
      line.setAttribute 'y2', e.clientY
      line.setAttribute 'stroke', 'black'
      line.setAttribute 'stroke-width', pressureWidth
      board.appendChild line
    dot = document.createElementNS SVGNS, 'circle'
    dot.setAttribute 'cx', e.clientX
    dot.setAttribute 'cy', e.clientY
    dot.setAttribute 'r', pressureWidth / 2
    board.appendChild dot
  board.addEventListener 'pointerdown', (e) ->
    e.preventDefault()
    pointers[e.pointerId] = makeDot e
  board.addEventListener 'pointerup', (e) ->
    e.preventDefault()
    delete pointers[e.pointerId]
  board.addEventListener 'pointermove', (e) ->
    e.preventDefault()
    return unless pointers[e.pointerId]
    pointers[e.pointerId] = makeDot e

Meteor.startup ->
  board = document.getElementById 'board'
  pointerEvents()
