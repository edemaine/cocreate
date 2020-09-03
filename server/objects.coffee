import {checkId} from '../lib/id.coffee'

Meteor.methods
  history: (room, page) ->
    @unblock()
    checkId room, 'room'
    checkId page, 'page'
    ObjectsDiff.find
      room: room
      page: page
    .fetch()
