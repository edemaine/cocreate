import {validId} from './id'

@Rooms = new Mongo.Collection 'rooms'

export checkRoom = (room) ->
  if validId(room) and data = Rooms.findOne room
    data
  else
    throw new Error "Invalid room ID #{room}"

Meteor.methods
  roomNew: (room = {}) ->
    check room,
      grid: Match.Optional Boolean
    ## Move room-level data to initial page
    page = {}
    for key in ['grid'] when key of room
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
