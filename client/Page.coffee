## Page class maintains the link between a room's page and the renderers,
## as well as maintaining the page's grid.

import {Tracker} from 'meteor/tracker'

import {Grid} from './Grid'
import {RenderObjects} from './RenderObjects'
import {RenderRemotes} from './RenderRemotes'

export class Page
  constructor: (@id, @room, @board, @remoteSVG) ->
    @board.clear()
    @grid = new Grid @
    @observeObjects()
    @observeRemotes()
    @board.onRetransform = =>
      @remotesRender.retransform()
      ## Update grid after `transform` attribute gets rendered.
      Meteor.setTimeout (=> @grid.update()), 0
    ## Automatically update grid
    @auto = Tracker.autorun =>
      unless @gridMode == (gridMode = @data()?.grid)
        @gridMode = gridMode
        Tracker.nonreactive => @grid.update()
  stop: ->
    @auto.stop()
    @board.onRetransform = null
    @render.stop()
    @remotesRender.stop()
    @objectsObserver.stop()
    @remotesObserver.stop()
  data: ->
    Pages.findOne @id
  observeObjects: ->
    @render = render = new RenderObjects @board
    @objectsObserver = Objects.find
      room: @room.id
      page: @id
    .observe
      added: (obj) ->
        render.shouldNotExist obj
        render.render obj
      changed: (obj, old) ->
        options = {}
        if old.pts?
          ## Assuming that pen's `pts` field changes only by appending
          options.start = old.pts.length
        for own key of obj when key != 'pts'
          options[key] = obj[key] != old[key]
        render.render obj, options
      removed: (obj) ->
        render.delete obj
  observeRemotes: ->
    @remotesRender = remotesRender = new RenderRemotes @board, @remoteSVG
    @remotesObserver = Remotes.find
      room: @room.id
      page: @id
    .observe
      added: (remote) -> remotesRender.render remote
      changed: (remote, oldRemote) -> remotesRender.render remote, oldRemote
      removed: (remote) -> remotesRender.delete remote
  resize: ->
    @grid.update()
    @remotesRender.resize()
