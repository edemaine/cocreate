import {validId} from '../lib/id.coffee'

Meteor.publish 'history', (room) ->
  check room, String
  unless validId room
    throw new Error "Invalid room ID #{id}"
  ObjectsDiff.find room: room
