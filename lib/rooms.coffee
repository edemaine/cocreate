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
  roomSetName: (roomId, name) ->
    check roomId, String
    check name, String
    room = checkRoom roomId
    Rooms.update room,
      $set: name: name
