@Rooms = new Mongo.Collection 'rooms'

Meteor.methods
  roomNew: ->
    room = {}
    unless @isSimulation
      now = new Date
      room.created = now
    Rooms.insert room
