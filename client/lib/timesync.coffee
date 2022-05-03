###
Maintain an approximate offset between client and server.
Based loosely on https://github.com/Meteor-Community-Packages/meteor-timesync/
Does multiple measurements and takes the median,
to ignore outliers from disconnect/reconnect.
###

updateInterval = 30 * 60 * 1000  # 30 minutes
medianOf = 3  # take median of this many updates

## Add this to a local time to get a remote time.
export offset = 0

## Get an approximate remote time (local operation, no waiting).
export remoteNow = -> Date.now() + offset

## Automatic updating:
measure = ->
  new Promise (done, error) ->
    t0 = Date.now()
    Meteor.call 'now', (error, ts) ->
      t3 = Date.now()
      if error
        console.warn "Failed to get time offset from server: #{error}"
        error error
      else
        ## NTP-style computation of offset
        done Math.round ((ts - t0) + (ts - t3)) / 2
export update = ->
  measures =
    for [0...medianOf]
      await measure()
  measures.sort (x, y) -> x - y
  offset = measures[Math.floor (medianOf - 1) / 2]

update()
Meteor.setInterval update, updateInterval
