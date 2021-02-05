import {Grid} from './Grid'
import {RenderObjects} from './RenderObjects'
import {RenderRemotes} from './RenderRemotes'
import {currentTool, selectTool} from './tools/tools'
import dom from './lib/dom'
import storage from './lib/storage'

export class Room
  constructor: (@id, @board) ->
    @page = new ReactiveVar
    @changePage null
    @stopped = new ReactiveVar
    @sub = Meteor.subscribe 'room', @id, onStop: => @stop()
    @auto = Tracker.autorun =>
      if @data()?.pages?.length
        @auto.stop()
        @changePage @data().pages[0] unless @page.get()?
    # @data = Rooms.findOne @id
    # return unless @data?
    # Tracker.nonreactive =>  # depend only on room data
    #   unless @page?
    #     @changePage @data.pages?[0]  # start on first page if not on a page
    #   document.getElementById('numPages').innerHTML =
    #     @data.pages?.length ? '?'
    @pageAuto = Tracker.autorun =>
      unless @pageGrid == (grid = Pages.findOne(@page.get())?.grid)
        @pageGrid = grid
        Tracker.nonreactive => @board.grid?.update()
    @gridSnap = new storage.Variable "#{@id}.gridSnap", false
  stop: ->
    @stopped.set true
    @gridSnap.stop()
    @auto.stop()
    @pageAuto.stop()
    @observe?.stop()
    @sub.stop()
    @roomObserveObjects?.stop()
    @roomObserveRemotes?.stop()
  loading: ->
    not (@stopped.get() or @sub.ready())
  data: ->
    Rooms.findOne @id
  bad: ->
    not @data()?.pages?.length
  pageData: ->
    Pages.findOne @page.get()
  changePage: (page) ->
    return if page == @page.get()
    # pageAttributes should maybe be in separate Page class
    @page.set page
    tools[currentTool.get()]?.stop?()
    @objectsObserver?.stop()
    @remotesObserver?.stop()
    @objectsObserver = @remotesObserver = null
    if page
      @observeObjects()  # sets @objectsObserver
      @observeRemotes()  # sets @remotesObserver
    else
      @board.clear()
    dom.classSet document.body, 'nopage', not page?
      # in particular, disable pointer events when no page
    selectTool null
  numPages: ->
    @data()?.pages?.length
  pageIndex: ->
    return unless pages = @data()?.pages
    index = pages.indexOf @page.get()
    return if index < 0
    index
  pageChangeDelta: (delta) ->
    return unless pages = @data()?.pages
    index = pages.indexOf @page.get()
    return if index < 0
    index += delta
    if 0 <= index < pages.length
      @changePage pages[index]
  observeObjects: ->
    @render?.stop()
    @render = render = new RenderObjects @board
    @board.clear()
    @board.grid = new Grid @
    @objectsObserver = Objects.find
      room: @id
      page: @page.get()
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
    @board.remotesRender = remotesRender = new RenderRemotes @
    @remotesObserver = Remotes.find
      room: @id
    .observe
      added: (remote) -> remotesRender.render remote
      changed: (remote, oldRemote) -> remotesRender.render remote, oldRemote
      removed: (remote) -> remotesRender.delete remote
