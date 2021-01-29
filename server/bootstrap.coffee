if process.env.COCREATE_SKIP_UPGRADE_DB
  return console.log 'Skipping database upgrades.'

## 'push' diffs used to just list a single point, but arrays are more helpful
## to deal with coalesced events, so make them all arrays.
## This update is slow, so it's disabled by default.
if false  # eslint-disable-line no-constant-condition
  ObjectsDiff.find
    type: 'push'
    pts: $not: $type: 'array'
  .forEach (diff) ->
    ObjectsDiff.update diff._id,
      $set: pts: [diff.pts]

## `pen` objects used to have no `width` attribute, and `pts` points' `w`
## attribute used to be an absolute width.  Now `w` is a multiplier for `width`.
Objects.find
  type: 'pen'
  width: $exists: false
.forEach (obj) ->
  return unless obj.pts?.length
  ws = (w for {w} in obj.pts)
  ###
  When this conversion code was written, the width assignment was between
  50% and 150% of target width, and allowed target widths are all integers.
  So the average between the min and max width we see, rounded to the nearest
  integer, is a good estimator for the true width.  Anyway, we don't have to
  be perfect; this is just to make the widths editable if desired.
  ###
  wMin = Math.min ...ws
  wMax = Math.max ...ws
  width = Math.max 1, Math.round (wMin + wMax) / 2
  scale = (x) ->
    for pt in x.pts
      pt.w /= width
  #console.log obj._id, width
  ObjectsDiff.find
    id: obj._id
    'pts.w': $exists: true
  .forEach (diff) ->
    #console.log 'before', (w for {w} in diff.pts)
    scale diff
    #console.log 'after', (w for {w} in diff.pts), '*', width
    ObjectsDiff.update diff._id,
      $set: pts: diff.pts
  #console.log 'before', (w for {w} in obj.pts)
  scale obj
  #console.log 'after', (w for {w} in obj.pts), '*', width
  Objects.update obj._id,
    $set:
      width: width
      pts: obj.pts

## Upgrade rooms to have (single) pages.
Rooms.find
  pages: $exists: false
.forEach (room) ->
  page = Meteor.apply 'pageNew', [
    room: room._id
  ], returnStubValue: true
  Rooms.update room._id,
    $set: pages: [page]
  for collection in [Objects, ObjectsDiff, Remotes]
    collection.update
      room: room._id
    ,
      $set: page: page
    ,
      multi: true
  console.log 'added page', page, 'to room', room._id

## Grid property of page instead of room.
Rooms.find
  grid: $exists: true
.forEach (room) ->
  Pages.update
    room: room._id
  ,
    $set: grid: room.grid
  ,
    multi: true
  Rooms.update room._id,
    $unset: grid: ''

console.log 'Upgraded database as necessary.'
