###
Client support library for remotes defined in /lib/remotes.coffee
###

import {Random} from 'meteor/random'
import * as throttle from './throttle.coffee'
export {fade} from '../../lib/remotes.coffee'

export id = Random.id()

###
Call remoteUpdate method, but wait for existing update to complete first,
to avoid stacking multiple remoteUpdates.
###
throttledUpdate = throttle.method 'remoteUpdate'
export update = (remote) ->
  remote._id = id
  throttledUpdate remote
