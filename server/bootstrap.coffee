## 'push' diffs used to just list a single point, but arrays are more helpful
## to deal with coalesced events, so make them all arrays.
ObjectsDiff.find
  type: 'push'
  pts: $not: $type: 'array'
.forEach (diff) ->
  ObjectsDiff.update diff._id,
    $set: pts: [diff.pts]
