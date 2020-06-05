Meteor.publish 'room', (room) ->
  check room, String
  [
    Rooms.find _id: room
    Objects.find room: room
  ]

Meteor.publish 'history', (room) ->
  check room, String
  ObjectsDiff.find room: room
