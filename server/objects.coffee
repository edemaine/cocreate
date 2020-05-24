import {validId} from '../lib/id.coffee'

Meteor.publish 'room', (room) ->
  check room, String
  Objects.find room: room

Objects.allow
  insert: (userId, obj) ->
    validId(obj.room) and
    Rooms.findOne(obj.room)?
  update: (userId, obj, fields) ->
    for field in fields
      return false unless field in ['pts']
    true
  remove: -> true
