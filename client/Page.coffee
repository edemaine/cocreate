## Page class maintains the link between a room's page and the renderers,
## as well as maintaining the page's grid.

import {Tracker} from 'meteor/tracker'

import {defaultTransform} from './Board'
import {Grid, defaultGridType} from './Grid'
import {RenderObjects} from './RenderObjects'
import {RenderRemotes} from './RenderRemotes'
import storage from './lib/storage'

## How long (in milliseconds) a page that was brought back keeps zooming to fit
## the images and formulas that are slow to show up
lateFitTime = 60000

noDiff =
  _id: true       # should never change
  type: true      # should never change
  pts: true       # use `start` instead
  created: true   # irrelevant to rendering, not properly compared
  updated: true   # irrelevant to rendering

export class Page
  constructor: (@id, @room, @board, @remoteSVG) ->
    @board.clear()
    @transform = new storage.Variable "#{@room.id}.#{@id}.transform",
      defaultTransform(), false
    ## Marker of the latest restoration (from deletion) that this browser has
    ## shown zoomed to fit; see `fitRestored`.
    @restoredSeen = new storage.Variable "#{@room.id}.#{@id}.restored",
      null, false
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
      ## A page that was brought back from deletion opens zoomed to fit,
      ## instead of in the view it had when it was deleted.
      if (restored = data?.restored)? and restored != @fitPending and
         restored != @restoredSeen.get()
        @fitPending = restored
        Tracker.nonreactive => @fitRestored restored
    ## Redraw grid once layout has settled, in case the board's size changed
    ## while this page was being set up.
    Meteor.defer => @grid.update() unless @stopped
  stop: ->
    @stopped = true
    @auto.stop()
    @fitAuto?.stop()
    @fitWait?()
    @board.onRetransform = null
    @render.stop()
    @remotesRender.stop()
    @objectsObserver.stop()
    @remotesObserver.stop()
  data: ->
    Pages.findOne @id
  ## Zoom to fit all objects (or reset the view if the page is empty), once
  ## the room has finished loading so that all objects are there, and their
  ## images and LaTeX formulas are displayed so that they are taken into account.
  ## If something is slow to show up, zoom to fit without it, and again as it
  ## shows up (for a while).  If the viewer pans or zooms in the meantime, their
  ## view stays.
  fitRestored: (restored) ->
    @fitAuto?.stop()
    @fitWait?()
    @fitAuto = Tracker.autorun (computation) =>
      return if @stopped or @room.loading()
      computation.stop()
      ## The view that this fits from: that of the viewer, until they change it
      view = @viewOf()
      ## Zoom to fit what is displayed, unless the viewer changed the view
      ## (then `false`)
      fit = =>
        return false unless @viewOf() == view
        elts = @board.renderedChildren()
        if elts.length
          @board.zoomToFit @board.renderedBBox elts
        else
          @board.setTransform defaultTransform()
        view = @viewOf()
        true
      stopLate = timer = null
      cancel = @render.whenSettled (settled) =>
        return if @stopped
        fit()
        @restoredSeen.set restored
        return if settled
        stopLate = @render.onArrival (settled) =>
          unless fit() and not settled
            stopLate()
            clearTimeout timer
          return
        timer = setTimeout stopLate, lateFitTime
        return
      @fitWait = ->
        cancel()
        stopLate?()
        clearTimeout timer
        return
  ## The current view, as something that can be compared with `==`
  viewOf: ->
    {x, y, scale} = @board.transform
    "#{x} #{y} #{scale}"
  observeObjects: ->
    @board.render = @render = new RenderObjects @board
    #dbvt_svg = dom.create 'g'
    @objectsObserver = Objects.find
      room: @room.id
      page: @id
    .observe
      added: (obj) =>
        @render.shouldNotExist obj
        @render.render obj
      changed: (obj, old) =>
        options = {}
        if old.pts?
          if old.type == 'pen'
            ## Assuming that pen's `pts` field changes only by appending
            options.start = old.pts.length
          else
            ## For other types such as `poly`, `rect`, `ellipse`, do a diff
            if old.pts.length == obj.pts.length
              for start in [0...old.pts.length]
                oldPt = old.pts[start]
                newPt = obj.pts[start]
                if oldPt.x != newPt.x or oldPt.y != newPt.y or oldPt.w != newPt.w
                  break
              options.start = start
        for own key of obj when key not of noDiff
          options[key] = obj[key] != old[key]
        @render.render obj, options
      removed: (obj) =>
        @render.delete obj
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
