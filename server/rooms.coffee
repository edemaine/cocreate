import {checkId} from '../lib/id'

Meteor.publish 'room', (room) ->
  checkId room, 'room'
  [
    Rooms.find _id: room
    Pages.find (room: room), channel: "rooms::#{room}::pages"
    PageDeletions.find (room: room), channel: "rooms::#{room}::pageDeletions"
    Remotes.find (room: room), channel: "rooms::#{room}::remotes"
    Objects.find (room: room), channel: "rooms::#{room}::objects"
  ]
