unless Meteor.isServer and Mongo.Collection.prototype.configureRedisOplog

  Originals =
    insert: Mongo.Collection.prototype.insert
    update: Mongo.Collection.prototype.update
    remove: Mongo.Collection.prototype.remove
    find: Mongo.Collection.prototype.find

  reconfig = (config) ->
    config unless config?.channel?
  Mongo.Collection.prototype.insert = (data, config) ->
    Originals.insert.call @, data, reconfig config
  Mongo.Collection.prototype.update = (selector, modifier, config) ->
    Originals.update.call @, selector, modifier, reconfig config
  Mongo.Collection.prototype.remove = (selector, config) ->
    Originals.remove.call @, selector, reconfig config
  Mongo.Collection.prototype.find = (selector = {}, config) ->
    Originals.find.call @, selector, reconfig config
