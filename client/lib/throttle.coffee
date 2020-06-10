###
Returns a function for calling the given Meteor method, but which waits for
existing updates to complete first, coalescing multiple updates while
waiting into the final update, to avoid stacking many method update calls.
###
export method = (name) ->
  ###
  `waiting` stores one of:
  * `false` (not currently waiting for server response, nothing queued up)
  * `true` (waiting for server response to an update, nothing queued up)
  * Array (waiting for server response to an update, then queued up to send
    these latest arguments to the method)
  ###
  waiting = false

  throttled = (...args) ->
    if waiting
      waiting = args
    else
      Meteor.call name, ...args, (error, result) ->
        if waiting
          if waiting == true
            waiting = false
          else
            nextArgs = waiting
            waiting = false
            throttled ...nextArgs
