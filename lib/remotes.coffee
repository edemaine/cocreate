###
"Remotes" refer to remote users/controls acting on a board.
They track the location of users' cursors/tools/views on board(s).
###

import {checkId} from './id.coffee'
import {checkRoom} from './rooms.coffee'

@Remotes = new Mongo.Collection 'remotes'

Meteor.methods
  remoteUpdate: (remote) ->
    check remote,
      _id: String
      room: String
      tool: String
      color: String
      cursor:
        x: Number
        y: Number
        w: Match.Optional Number
    checkId remote._id, 'remote'
    checkRoom remote.room
    unless @isSimulation
      remote.updated = new Date
    Remotes.upsert remote._id, remote
