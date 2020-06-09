import {validId} from '../lib/id.coffee'

Meteor.publish 'room', (room) ->
  check room, String
  unless validId room
    throw new Error "Invalid room ID #{id}"
  [
    Rooms.find _id: room
    Objects.find room: room
  ]
