import {check, Match} from 'meteor/check'
import {Mongo} from 'meteor/mongo'

import {validId} from './id'
import {validGridType} from './grid'

@Rooms = new Mongo.Collection 'rooms'

export checkRoom = (room) ->
  if validId(room) and data = Rooms.findOne room
    data
  else
    throw new Meteor.Error "Invalid room ID #{room}"

Meteor.methods
  roomNew: (room = {}) ->
    check room,
      grid: Match.Optional Boolean
      gridType: Match.Optional Match.Where validGridType
    ## Move page-level data to initial page
    page = {}
    for key in ['grid', 'gridType'] when key of room
      page[key] = room[key]
      delete room[key]
    unless @isSimulation
      now = new Date
      room.created = now
    room.pages = []
    roomId = Rooms.insert room
    page.room = roomId
    pageId = Meteor.apply 'pageNew', [page], returnStubValue: true
    room: roomId
    page: pageId

  ## Duplicate an entire room/board (all pages and all objects) into a brand
  ## new room with its own URL, leaving the original untouched.  Returns the
  ## new room's ID.  Server-only: the caller awaits the result, so this works
  ## even when the visitor hasn't subscribed to the source room.
  roomDup: (roomId) ->
    check roomId, String
    return if @isSimulation
    room = checkRoom roomId
    sourcePages = room.pages ? []
    delete room._id
    delete room.created
    room.created = new Date
    room.pages = []
    newRoomId = Rooms.insert room
    for pageId in sourcePages
      page = Pages.findOne pageId
      continue unless page?
      delete page._id
      delete page.created
      page.room = newRoomId
      newPageId = Meteor.apply 'pageNew', [page]
      Objects.find
        room: roomId
        page: pageId
      .forEach (obj) ->
        delete obj._id
        delete obj.created
        delete obj.updated
        obj.room = newRoomId
        obj.page = newPageId
        Meteor.call 'objectNew', obj
    newRoomId
