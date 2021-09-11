import {check, Match} from 'meteor/check'
import {Mongo} from 'meteor/mongo'

import {validId} from './id'
import {checkRoom} from './rooms'
import {checkPage} from './pages'
import {validUrl} from './url'

@Objects = new Mongo.Collection 'objects'
@ObjectsDiff = new Mongo.Collection 'objects.diff' if Meteor.isServer

ObjectsDiff?.configureRedisOplog?(
  mutation: (options) -> options.pushToRedis = false
)

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
    throw new Meteor.Error "Invalid object ID #{id}"

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
      opacity: Match.Optional Number
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
          fill: Match.Optional String
          width: Number
      when 'text'
        Object.assign pattern,
          pts: Match.Where (pts) ->
            check pts, [xyType]
            pts.length == 1
          color: String
          text: String
          fontSize: Number
      when 'image'
        Object.assign pattern,
          pts: Match.Where (pts) ->
            check pts, [xyType]
            pts.length == 1
          url: Match.Where validUrl
          credentials: Match.Optional Boolean
          proxy: Match.Optional Boolean
      else
        throw new Meteor.Error "Invalid type #{obj?.type} for object"
    check obj, pattern
    unless @isSimulation
      checkRoom obj.room
      checkPage obj.page
      if obj._id? and Objects.findOne(obj._id)?
        throw new Meteor.Error "Attempt to create duplicate object #{obj._id}"
      now = new Date
      obj.created ?= now
      obj.updated ?= now
    id = Objects.insert obj, channel: "rooms::#{obj.room}::objects"
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
    , channel: "rooms::#{diff.room}::objects"
  objectEdit: (diff) ->
    id = diff?.id
    obj = checkObject id
    pattern =
      id: String
      tx: Match.Optional Number
      ty: Match.Optional Number
      pts: Match.Optional Match.Where (pts) ->
        return false unless typeof pts == 'object'
        for key, value of pts
          return false unless /^\d+$/.test key
          check value, xyType
        true
      opacity: Match.Optional Match.OneOf Number, null  # null to turn off
    unless obj.type == 'image'
      Object.assign pattern,
        color: Match.Optional String
    if obj.type in ['pen', 'poly', 'rect', 'ellipse']
      Object.assign pattern,
        width: Match.Optional Number
    if obj.type in ['rect', 'ellipse']
      Object.assign pattern,
        fill: Match.Optional Match.OneOf String, null  # null to turn off
    if obj.type == 'text'
      Object.assign pattern,
        text: Match.Optional String
        fontSize: Match.Optional Number
    if obj.type == 'image'
      Object.assign pattern,
        url: Match.Optional String
        credentials: Match.Optional Boolean
        proxy: Match.Optional Boolean
    check diff, pattern
    set = {}
    for key, value of diff when key != 'id'
      switch key
        when 'pts'
          for subkey, subvalue of value
            set["#{key}.#{subkey}"] = subvalue
        else
          set[key] = value
    unless @isSimulation
      diff.room = obj.room
      diff.page = obj.page
      diff.type = 'edit'
      diff.updated = set.updated = new Date
      ObjectsDiff.insert diff
    Objects.update id,
      $set: set
    , channel: "rooms::#{obj.room}::objects"
  objectsEdit: (diffs) ->
    ## Combine multiple edit operations into a single RPC
    check diffs, [Object]
    for diff in diffs
      Meteor.call 'objectEdit', diff
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
    Objects.remove id, channel: "rooms::#{obj?.room}::objects"
