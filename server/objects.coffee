import {checkId} from '../lib/id.coffee'

Meteor.publish 'history', (room) ->
  checkId room, 'room'
  ObjectsDiff.find room: room
