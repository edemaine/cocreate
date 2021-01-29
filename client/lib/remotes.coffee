###
Client support library for remotes defined in /lib/remotes.coffee
###

import {Random} from 'meteor/random'
import throttle from './throttle'
import {validId} from '/lib/id'
export {fade} from '/lib/remotes'

export id = null
try
  id = window?.sessionStorage?.getItem? 'remoteId'
unless validId id
  id = Random.id()
  try
    window?.sessionStorage?.setItem? 'remoteId', id

###
Call remoteUpdate method, but throttled to 66 ms ~ 1/15 sec i.e. 15fps.
###
throttledUpdate = throttle.method 'remoteUpdate', null, 66
export update = (remote) ->
  remote._id = id
  throttledUpdate remote
