import {validId} from './id.coffee'

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
    unless @isSimulation
      now = new Date
      room.created = now
    room.pages = []
    roomId = Rooms.insert room
    pageId = Meteor.apply 'pageNew', [
      room: roomId
    ], returnStubValue: true
    room: roomId
    page: pageId

  roomGridToggle: (room) ->
    check room, String
    data = checkRoom room
    Rooms.update room,
      $set: grid: not data.grid
