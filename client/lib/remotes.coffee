###
Client support library for remotes defined in /lib/remotes.coffee
###

import {Random} from 'meteor/random'

export id = Random.id()

###
`waiting` stores one of:
* `false` (not currently waiting for server response, nothing queued up)
* `true` (waiting for server response to an update, nothing queued up)
* object (waiting for server response to an update, then plan to send this
  object as the latest update)
###
waiting = false

###
Call remoteUpdate method, but wait for existing update to complete first,
to avoid stacking multiple remoteUpdates.
###
export update = (remote) ->
  remote._id = id
  if waiting
    waiting = remote
  else
    Meteor.call 'remoteUpdate', remote, (error, result) ->
      if waiting
        if waiting == true
          waiting = false
        else
          remote = waiting
          waiting = false
          remoteUpdate remote
