###
"Remotes" refer to remote users/controls acting on a board.
They track the location of users' cursors/tools/views on board(s).
###

import {check, Match} from 'meteor/check'
import {Mongo} from 'meteor/mongo'

import {checkId} from './id'
#import {checkRoom} from './rooms'
#import {checkPage} from './pages'
export fade = 60

@Remotes = new Mongo.Collection 'remotes'

Meteor.methods
  remoteUpdate: (remote) ->
    @unblock()
    check remote,
      _id: String
      name: Match.Optional String
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
      ## For efficiency, don't bother checking that room and page are valid;
      ## an invalid remote won't hurt anything.
      #checkRoom remote.room
      #checkPage remote.page
      remote.updated = new Date
    Remotes.upsert remote._id, remote, channel: "rooms::#{remote.room}::remotes"
