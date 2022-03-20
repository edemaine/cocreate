## Page class maintains the link between a room's page and the renderers,
## as well as maintaining the page's grid.

import {Tracker} from 'meteor/tracker'

import {defaultTransform} from './Board'
import {Grid, defaultGridType} from './Grid'
import {RenderObjects} from './RenderObjects'
import {RenderRemotes} from './RenderRemotes'
import {BBox} from './BBox'
import {DBVT} from './DBVT'
import dom from './lib/dom'
import storage from './lib/storage'

noDiff =
  _id: true       # should never change
  type: true      # should never change
  pts: true       # use `start` instead
  created: true   # irrelevant to rendering, not properly compared
  updated: true   # irrelevant to rendering

export class Page
  constructor: (@id, @room, @board, @remoteSVG) ->
    @board.clear()
    @bbox = {}
    @dbvt = new DBVT()
    @transform = new storage.Variable "#{@room.id}.#{@id}.transform",
      defaultTransform(), false
    @board.setTransform @transform.get()
    @grid = new Grid @
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
      data = @data()
      gridMode =
        if data?.grid
          data.gridType ? defaultGridType
        else
          false
      unless @gridMode == gridMode
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
  id2dom: (id) ->
    @render.dom[id]
  observeObjects: ->
    @render = new RenderObjects @board
    #dbvt_svg = dom.create 'g'
    @objectsObserver = Objects.find
      room: @room.id
      page: @id
    .observe
      added: (obj) =>
        @render.shouldNotExist obj
        @render.render obj
        @bbox[obj._id] = bbox = dom.svgBBox @board.svg, @render.dom[obj._id], @board.root
        @dbvt.insert obj._id, bbox
        #@board.root.appendChild @dbvt.exportDebugSVG dbvt_svg
      changed: (obj, old) =>
        bbox = @bbox[obj._id]
        options = {}
        if old.pts?
          if old.type == 'pen'
            ## Assuming that pen's `pts` field changes only by appending
            options.start = old.pts.length
          else
            ## For other types such as `poly`, `rect`, `ellipse`, do a diff
            for start in [0...old.pts.length]
              oldPt = old.pts[start]
              newPt = obj.pts[start]
              if oldPt.x != newPt.x or oldPt.y != newPt.y or oldPt.w != newPt.w
                break
            options.start = start
        for own key of obj when key not of noDiff
          options[key] = obj[key] != old[key]
        @render.render obj, options
        ## BBox update
        if obj.type == 'pen' and not options.width # only points are added
          for i in [options.start...obj.pts.length]
            bbox = bbox.union (BBox.fromPoint obj.pts[i]).fattened (obj.width / 2)
        else
          bbox = dom.svgBBox @board.svg, @render.dom[obj._id], @board.root
        @bbox[obj._id] = bbox
        @dbvt.move obj._id, bbox
        #@board.root.appendChild @dbvt.exportDebugSVG dbvt_svg
      removed: (obj) =>
        @render.delete obj
        @dbvt.remove obj._id
        delete @bbox[obj._id]
        #@board.root.appendChild @dbvt.exportDebugSVG dbvt_svg
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
