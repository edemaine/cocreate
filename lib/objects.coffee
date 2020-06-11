import {validId} from './id.coffee'
import {checkRoom} from './rooms.coffee'

@Objects = new Mongo.Collection 'objects'
@ObjectsDiff = new Mongo.Collection 'objects.diff'

xyType =
  x: Number
  y: Number
xywType =
  x: Number
  y: Number
  w: Number

export checkObject = (id) ->
  if validId(id) and obj = Objects.findOne id
    obj
  else
    throw new Error "Invalid object ID #{id}"

Meteor.methods
  objectNew: (obj) ->
    switch obj?.type
      when 'pen'
        check obj,
          _id: Match.Optional String
          created: Match.Optional Date
          updated: Match.Optional Date
          room: String
          type: 'pen'
          pts: [xywType]
          color: String
      when 'poly'
        check obj,
          _id: Match.Optional String
          created: Match.Optional Date
          updated: Match.Optional Date
          room: String
          type: 'poly'
          pts: [xyType]
          color: String
          width: Number
      when 'rect'
        check obj,
          _id: Match.Optional String
          created: Match.Optional Date
          updated: Match.Optional Date
          room: String
          type: 'rect'
          pts: Match.Where (pts) ->
            check pts, [xyType]
            pts.length == 2
          color: String
          width: Number
      else
        throw new Error "Invalid type #{obj?.type} for object"
    unless @isSimulation
      checkRoom obj.room
      if obj._id? and Objects.findOne(obj._id)?
        throw new Error "Attempt to create duplicate object #{obj._id}"
      now = new Date
      obj.created ?= now
      obj.updated ?= now
    id = Objects.insert obj
    unless @isSimulation
      delete obj._id
      obj.id = id
      ObjectsDiff.insert obj
    id
  objectPush: (diff) ->
    check diff,
      id: String
      pts: [xywType]
    id = diff.id
    unless @isSimulation
      obj = checkObject id
      diff.room = obj.room
      diff.type = 'push'
      diff.updated = new Date
      ObjectsDiff.insert diff
    Objects.update id,
      $push: pts: $each: diff.pts
      $set:
        unless @isSimulation
          updated: diff.updated
        else
          {}
  objectEdit: (diff) ->
    check diff,
      id: String
      color: Match.Optional String
      width: Match.Optional Number
      pts: Match.Optional Match.Where (pts) ->
        return false unless typeof pts == 'object'
        for key, value of pts
          return false unless /^\d+$/.test key
          check value, xyType
        true
    id = diff.id
    set = {}
    for key, value of diff
      switch key
        when 'color', 'width'
          set[key] = value
        when 'pts'
          for subkey, subvalue of value
            set["#{key}.#{subkey}"] = subvalue
    unless @isSimulation
      obj = checkObject id
      diff.room = obj.room
      diff.type = 'edit'
      diff.updated = set.updated = new Date
      ObjectsDiff.insert diff
    Objects.update id,
      $set: set
  objectDel: (id) ->
    check id, String
    unless @isSimulation
      obj = checkObject id
      ObjectsDiff.insert
        id: id
        room: obj.room
        type: 'del'
        updated: new Date
    Objects.remove id
