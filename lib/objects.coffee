import {validId} from './id.coffee'
import {checkRoom} from './rooms.coffee'
import {checkPage} from './pages.coffee'

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
    pattern =
      _id: Match.Optional String
      type: String
      room: String
      page: String
      created: Match.Optional Date
      updated: Match.Optional Date
      tx: Match.Optional Number
      ty: Match.Optional Number
    switch obj?.type
      when 'pen'
        Object.assign pattern,
          pts: [xywType]
          color: String
          width: Number
      when 'poly'
        Object.assign pattern,
          pts: [xyType]
          color: String
          width: Number
      when 'rect', 'ellipse'
        Object.assign pattern,
          pts: Match.Where (pts) ->
            check pts, [xyType]
            pts.length == 2
          color: String
          width: Number
      when 'text'
        Object.assign pattern,
          pts: Match.Where (pts) ->
            check pts, [xyType]
            pts.length == 1
          color: String
          text: String
      else
        throw new Error "Invalid type #{obj?.type} for object"
    check obj, pattern
    unless @isSimulation
      checkRoom obj.room
      checkPage obj.page
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
      diff.page = obj.page
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
      text: Match.Optional String
      tx: Match.Optional Number
      ty: Match.Optional Number
    id = diff.id
    set = {}
    for key, value of diff when key != 'id'
      switch key
        when 'pts'
          for subkey, subvalue of value
            set["#{key}.#{subkey}"] = subvalue
        else
          set[key] = value
    unless @isSimulation
      obj = checkObject id
      diff.room = obj.room
      diff.page = obj.page
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
        page: obj.page
        type: 'del'
        updated: new Date
    Objects.remove id
