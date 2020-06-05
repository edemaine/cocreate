@Rooms = new Mongo.Collection 'rooms'

Meteor.methods
  roomNew: ->
    room = {}
    unless @isSimulation
      now = new Date
      room.created = now
    Rooms.insert room

  roomGridToggle: (room) ->
    check room, String
    unless data = Rooms.findOne room
      return console.error "Invalid room ID #{room}"
    Rooms.update room,
      $set: grid: not data.grid
