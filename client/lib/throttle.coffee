export delay = 33  # 33 ms ~ 1/30 sec i.e. 30fps

###
Returns a function for calling the given Meteor method repeatedly, but only
actually calls the method after `delay` milliseconds, coalescing multiple
updates while waiting into the final update, to avoid stacking many method
update calls.  By default, new calls just overwrite older unsent calls, but
you can specify `coallescer(older, newer)` to provide a custom reducer that
combines older and newer call arguments (e.g. concatenating).
###
export method = (name, coallescer) ->
  ###
  `waiting` stores one of:
  * `null` (not currently waiting for timer, nothing queued up)
  * Array (waiting for timer, then queued up to send these arguments to method)
  ###
  waiting = null

  throttled = (...args) ->
    if waiting?
      if coallescer?
        waiting = coallescer waiting, args  # combine with existing update
      else
        waiting = args  # overwrite any existing update
    else
      waiting = args
      Meteor.setTimeout ->
        args = waiting
        waiting = null
        Meteor.call name, ...args
      , delay

###
Returns a function for calling the given Meteor method, but which waits for
existing updates to complete first, coalescing multiple updates while
waiting into the final update, to avoid stacking many method update calls.
###
#export methodToFinish = (name) ->
  ###
  `waiting` stores one of:
  * `false` (not currently waiting for server response, nothing queued up)
  * `true` (waiting for server response to an update, nothing queued up)
  * Array (waiting for server response to an update, then queued up to send
    these latest arguments to the method)
  ###
###
  waiting = false

  throttled = (...args) ->
    if waiting
      waiting = args  # overwrite any existing update
    else
      waiting = true
      Meteor.call name, ...args, (error, result) ->
        if waiting
          if waiting == true  # nothing queued up
            waiting = false
          else                # do update on queue
            nextArgs = waiting
            waiting = false
            throttled ...nextArgs
###
