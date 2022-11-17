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
dashType = Match.Where (x) ->
  x == null or (
    typeof x == 'string' and
    /^[\d.\s]+$/.test x
  )

export checkObject = (id) ->
  if validId(id) and obj = Objects.findOne id
    obj
  else
    throw new Meteor.Error "Invalid object ID #{id}"

addAttributePattern = (pattern, type, edit) ->
  optionalIfEdit = if edit then Match.Optional else (x) => x
  pattern.tx = pattern.ty = Match.Optional Number
  pattern.opacity = Match.Optional Match.OneOf Number, null  # null to turn off
  unless type == 'image'
    pattern.color = optionalIfEdit String
  if type in ['pen', 'poly', 'rect', 'ellipse']
    pattern.width = optionalIfEdit Number
    pattern.dash = Match.Optional dashType
  if type in ['pen', 'poly']
    pattern.arrowStart = pattern.arrowEnd =
      Match.Optional Match.OneOf 'arrow', null  # null for no arrowhead
  if type in ['rect', 'ellipse']
    pattern.fill = Match.Optional Match.OneOf String, null  # null to turn off
  if type == 'text'
    pattern.text = optionalIfEdit String
    pattern.fontSize = optionalIfEdit Number
  if type == 'image'
    pattern.url = optionalIfEdit Match.Where validUrl
    pattern.credentials = Match.Optional Boolean
    pattern.proxy = Match.Optional Boolean

Meteor.methods
  objectNew: (obj) ->
    pattern =
      _id: Match.Optional String
      type: String
      room: String
      page: String
      created: Match.Optional Date
      updated: Match.Optional Date
    addAttributePattern pattern, obj.type
    switch obj?.type
      when 'pen'
        pattern.pts = [xywType]
      when 'poly'
        pattern.pts = [xyType]
      when 'rect', 'ellipse'
        pattern.pts = Match.Where (pts) ->
          check pts, [xyType]
          pts.length == 2
      when 'text'
        pattern.pts = Match.Where (pts) ->
          check pts, [xyType]
          pts.length == 1
      when 'image'
        pattern.pts = Match.Where (pts) ->
          check pts, [xyType]
          pts.length == 1
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
      check obj.type, 'pen'
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
      pts: Match.Optional Match.Where (pts) ->
        return false unless typeof pts == 'object' # includes Array
        ptType = if obj.type == 'pen' then xywType else xyType
        for key, value of pts
          return false unless /^\d+$/.test key
          key = parseInt key, 10
          return false if key < 0
          check value, ptType
          switch obj.type
            when 'rect', 'ellipse'
              return false unless key < 2
            when 'text'
              return false unless key < 1
            when 'image'
              return false unless key < 1
        true
    addAttributePattern pattern, obj.type, true
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
