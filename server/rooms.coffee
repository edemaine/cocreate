import {checkId} from '../lib/id'

Meteor.publish 'room', (room) ->
  checkId room, 'room'
  [
    Rooms.find _id: room
    Pages.find (room: room), channel: "rooms::#{room}::pages"
    Remotes.find (room: room), channel: "rooms::#{room}::remotes"
    Objects.find (room: room), channel: "rooms::#{room}::objects"
  ]
