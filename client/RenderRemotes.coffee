## RenderRemotes class draws the remote cursors into an SVG overlay
## for a board (in practice, of the main board).

import icons from './lib/icons'
import dom from './lib/dom'
import remotes from './lib/remotes'
import timesync from './lib/timesync'
import {defaultColor} from './tools/color'
import {drawingTools, tools} from './tools/tools'
import {drawingToolIcon} from './cursor'

remoteIconSize = 24
remoteIconOutside = 0.2  # fraction to render icons outside view

export class RenderRemotes
  constructor: (@board, @svg) ->
    @elts = {}
    @updated = {}
    @transforms = {}
    @svg.innerHTML = ''
    @svg.appendChild @root = dom.create 'g'
    @resize()
    @interval = setInterval =>
      @timer()
    , 1000
  stop: ->
    clearInterval @interval
  render: (remote, oldRemote = {}) ->
    id = remote._id
    return if id == remotes.id  # don't show own cursor
    @updated[id] = remote.updated
    ## Omit this in case remoteNow() is inaccurate at startup:
    #return if (timesync.remoteNow() - @updated[id]) / 1000 > remotes.fade
    unless (elt = @elts[id])?
      @elts[id] = elt = dom.create 'g'
      @root.appendChild elt
    unless remote.tool == oldRemote.tool and remote.color == oldRemote.color and
           remote.fill == oldRemote.fill
      if (icon = tools[remote.tool]?.icon)?
        if remote.tool of drawingTools
          icon = drawingToolIcon remote.tool,
            (remote.color ? defaultColor), remote.fill
        elt.innerHTML = icons.cursorIcon icon, ...tools[remote.tool].hotspot
        elt.appendChild dom.create 'text',
          dx: icons.cursorSize + 2
          dy: icons.cursorSize / 2 + 6  # for 16px default font size
        oldRemote?.name = null  # force text update
      else
        elt.innerHTML = ''
        return  # don't set transform or opacity
    text = elt.childNodes[1]
    unless remote.name == oldRemote.name
      text.innerHTML = dom.escape remote.name ? ''
    visible = remote.cursor? # and remote.page == currentPage.get().id
    if visible
      elt.style.visibility = null
    else
      elt.style.visibility = 'hidden'
      delete @transforms[id]
      return
    elt.style.opacity = 1 -
      (timesync.remoteNow() - @updated[id]) / 1000 / remotes.fade
    hotspot = tools[remote.tool]?.hotspot ? [0,0]
    minX = (hotspot[0] - remoteIconOutside) * remoteIconSize
    minY = (hotspot[1] - remoteIconOutside) * remoteIconSize
    do @transforms[id] = =>
      maxX = @board.clientBBox.width - (1 - hotspot[0] - remoteIconOutside) * remoteIconSize
      maxY = @board.clientBBox.height - (1 - hotspot[1] - remoteIconOutside) * remoteIconSize
      x = (remote.cursor.x + @board.transform.x) * @board.transform.scale
      y = (remote.cursor.y + @board.transform.y) * @board.transform.scale
      unless (goodX = (minX <= x <= maxX)) and
             (goodY = (minY <= y <= maxY))
        x1 = @board.clientBBox.width / 2
        y1 = @board.clientBBox.height / 2
        x2 = x
        y2 = y
        unless goodX
          if x < minX
            x3 = minX
          else if x > maxX
            x3 = maxX
          ## https://mathworld.wolfram.com/Two-PointForm.html
          y3 = y1 + (y2 - y1) / (x2 - x1) * (x3 - x1)
        unless goodY
          if y < minY
            y4 = minY
          else if y > maxY
            y4 = maxY
          x4 = x1 + (x2 - x1) / (y2 - y1) * (y4 - y1)
        if goodX or minX <= x4 <= maxX
          x = x4
          y = y4
        else if goodY or minY <= y3 <= maxY
          x = x3
          y = y3
        else
          x = x3
          y = y3
          if x < minX
            x = minX
          else if x > maxX
            x = maxX
          if y < minY
            y = minY
          else if y > maxY
            y = maxY
      elt.setAttribute 'transform', """
        translate(#{x} #{y})
        scale(#{remoteIconSize})
        translate(#{-hotspot[0]} #{-hotspot[1]})
        scale(#{1/icons.cursorSize})
      """
      if x >= 0.8 * maxX + 0.2 * minX
        dom.attr text,
          dx: -2
          'text-anchor': 'end'
      else
        dom.attr text,
          dx: icons.cursorSize + 2
          'text-anchor': 'start'
  delete: (remote) ->
    id = remote._id ? remote
    if (elt = @elts[id])?
      elt.remove()
      delete @elts[id]
      delete @transforms[id]
  resize: ->
    #@svg.setAttribute 'viewBox', "0 0 #{@board.clientBBox.width} #{@board.clientBBox.height}"
    @retransform()
  retransform: ->
    for id, transform of @transforms
      transform()
  timer: (elt, id) ->
    now = timesync.remoteNow()
    for id, elt of @elts
      elt.style.opacity = 1 - (now - @updated[id]) / 1000 / remotes.fade
