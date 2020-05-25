import {validId} from './id.coffee'

@Objects = new Mongo.Collection 'objects'
@ObjectsDiff = new Mongo.Collection 'objects.diff'

xywType =
  x: Number
  y: Number
  w: Number

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
      else
        throw new Error "Invalid type #{obj?.type} for object"
    unless @isSimulation
      unless validId(obj.room) and Rooms.findOne(obj.room)?
        throw new Error "Invalid room #{obj.room} for object"
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
      pts: xywType
    id = diff.id
    unless @isSimulation
      unless validId(id) and (obj = Objects.findOne(id))?
        throw new Error "Invalid object ID #{id} for mod"
      diff.room = obj.room
      diff.type = 'push'
      diff.updated = new Date
      ObjectsDiff.insert diff
    Objects.update diff.id,
      $push: pts: diff.pts
      $set:
        unless @isSimulation
          updated: diff.updated
        else
          {}
  objectDel: (id) ->
    check id, String
    unless @isSimulation
      unless validId(id) and (obj = Objects.findOne(id))?
        throw new Error "Invalid object ID #{id} for deletion"
      ObjectsDiff.insert
        id: id
        room: obj.room
        type: 'del'
        updated: new Date
    Objects.remove id
