## Room maintains the database subscription for a room, tracks when it loads,
## and tracks room-global data like the page list and grid snapping mode.

import {ReactiveVar} from 'meteor/reactive-var'

import storage from './lib/storage'

export class Room
  constructor: (@id) ->
    @stopped = new ReactiveVar
    @waiting = new ReactiveVar 0
    @sub = Meteor.subscribe 'room', @id, onStop: => @stop()
    @gridSnap = new storage.Variable "#{@id}.gridSnap", false
    @gridHalfSnap = new storage.Variable "#{@id}.gridHalfSnap", false
  stop: ->
    @stopped.set true
    @gridSnap.stop()
    @sub.stop()
  loading: ->
    @waiting.get() or not (@stopped.get() or @sub.ready())
  changeWaiting: (delta) ->
    @waiting.set @waiting.get() + delta
  data: ->
    Rooms.findOne @id
  bad: ->
    not @loading() and
    not @data()?.pages?.length
  numPages: ->
    @data()?.pages?.length
  pageIndex: (page) ->
    return unless page?
    return unless (pages = @data()?.pages)?
    index = pages.indexOf (page.id ? page)
    return if index < 0
    index
  pageDelta: (page, delta) ->
    return unless (pages = @data()?.pages)?
    index = pages.indexOf (page.id ? page)
    return if index < 0
    index += delta
    if 0 <= index < pages.length
      pages[index]
