###
"Remotes" refer to remote users/controls acting on a board.
They track the location of users' cursors/tools/views on board(s).
###

import {checkId} from './id.coffee'
import {checkRoom} from './rooms.coffee'
import {checkPage} from './pages.coffee'
export fade = 60

@Remotes = new Mongo.Collection 'remotes'

Meteor.methods
  remoteUpdate: (remote) ->
    @unblock()
    check remote,
      _id: String
      room: String
      page: String
      tool: String
      color: String
      fill: Match.Optional String
      cursor:
        x: Number
        y: Number
        w: Match.Optional Number
    checkId remote._id, 'remote'
    unless @isSimulation
      checkRoom remote.room
      checkPage remote.page
      remote.updated = new Date
    Remotes.upsert remote._id, remote
