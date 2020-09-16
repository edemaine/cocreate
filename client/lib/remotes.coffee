###
Client support library for remotes defined in /lib/remotes.coffee
###

import {Random} from 'meteor/random'
import * as throttle from './throttle.coffee'
export {fade} from '../../lib/remotes.coffee'

export id = window?.sessionStorage?.getItem? 'remoteId'
unless id
  window?.sessionStorage?.setItem? 'remoteId', id = Random.id()

###
Call remoteUpdate method, but throttled to 66 ms ~ 1/15 sec i.e. 15fps.
###
throttledUpdate = throttle.method 'remoteUpdate', null, 66
export update = (remote) ->
  remote._id = id
  throttledUpdate remote
