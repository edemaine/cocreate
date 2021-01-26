###
Maintain an approximate offset between client and server.
Based loosely on https://github.com/Meteor-Community-Packages/meteor-timesync/
###

updateInterval = 60 * 1000  # 1 minute

## Add this to a local time to get a remote time.
export offset = 0

## Get an approximate remote time (local operation, no waiting).
export remoteNow = -> Date.now() + offset

## Automatic updating:
export update = ->
  t0 = Date.now()
  Meteor.call 'now', (error, ts) ->
    t3 = Date.now()
    if error
      return console.warn "Failed to get time offset from server: #{error}"
    ## NTP-style computation of offset
    offset = Math.round ((ts - t0) + (ts - t3)) / 2
update()
Meteor.setInterval update, updateInterval
