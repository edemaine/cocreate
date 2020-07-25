import {checkId} from '../lib/id.coffee'

Meteor.publish 'history', (room, page) ->
  checkId room, 'room'
  checkId page, 'page'
  ObjectsDiff.find
    room: room
    page: page
