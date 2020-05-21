import {validId} from '../lib/id.coffee'

Rooms.allow
  insert: (userId, room) ->
    check room, {}
    true
  update: -> false
  remove: -> false
