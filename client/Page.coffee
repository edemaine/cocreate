## Page class maintains the link between a room's page and the renderers,
## as well as maintaining the page's grid.

# Used for DBVT debugging
#import dom from './lib/dom'

import {Tracker} from 'meteor/tracker'

import {defaultTransform} from './Board'
import {Grid} from './Grid'
import {RenderObjects} from './RenderObjects'
import {RenderRemotes} from './RenderRemotes'
import {Aabb, Dbvt} from './Dbvt'
import storage from './lib/storage'

export class Page
  constructor: (@id, @room, @board, @remoteSVG) ->
    @board.clear()
    @dbvt = new Dbvt()
    @transform = new storage.Variable "#{@room.id}.#{@id}.transform",
      defaultTransform(), false
    @board.setTransform @transform.get()
    @grid = new Grid @
    @objMap = {}
    @observeObjects()
    @observeRemotes()
    @board.onRetransform = =>
      @remotesRender.retransform()
      ## Update grid after `transform` attribute gets rendered.
      Meteor.setTimeout (=> @grid.update()), 0
      ## Save current view in localStorage
      @transform.set @board.transform
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
  eltMap: ->
    @render.dom
  observeObjects: ->
    @render = render = new RenderObjects @board
    dbvt = @dbvt
    board = @board
    objMap = @objMap
    #dbvt_svg = dom.create 'g'
    @objectsObserver = Objects.find
      room: @room.id
      page: @id
    .observe
      added: (obj) ->
        objMap[obj._id] = obj
        render.shouldNotExist obj
        render.render obj
        obj.aabb = Aabb.fromObj obj, board.svg, board.root, render.dom
        dbvt.insert obj._id, obj.aabb
        #board.root.appendChild dbvt.exportDebugSVG dbvt_svg
      changed: (obj, old) ->
        obj.aabb = objMap[obj._id].aabb
        objMap[obj._id] = obj
        options = {}
        if old.pts?
          ## Assuming that pen's `pts` field changes only by appending
          options.start = old.pts.length
        for own key of obj when key != 'pts'
          options[key] = obj[key] != old[key]
        render.render obj, options
        ## AABB update
        if obj.type == 'pen' && !options.width # only points are added
          for i in [options.start...obj.pts.length]
            obj.aabb = obj.aabb.union (Aabb.fromPoint obj.pts[i]).fattened (obj.width / 2)
        else
          obj.aabb = Aabb.fromObj obj, board.svg, board.root, render.dom
        dbvt.move obj._id, obj.aabb
        #board.root.appendChild dbvt.exportDebugSVG dbvt_svg
      removed: (obj) ->
        delete objMap[obj._id]
        render.delete obj
        dbvt.remove obj._id
        #board.root.appendChild dbvt.exportDebugSVG dbvt_svg
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
