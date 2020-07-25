import {validId} from './id.coffee'
import {checkRoom} from './rooms.coffee'

@Pages = new Mongo.Collection 'pages'

export checkPage = (page) ->
  if validId(page) and data = Pages.findOne page
    data
  else
    throw new Error "Invalid page ID #{page}"

Meteor.methods
  pageNew: (page) ->
    check page,
      room: String
    unless @isSimulation
      now = new Date
      page.created = now
    roomId = page.room
    room = checkRoom roomId
    pageId = Pages.insert page
    Rooms.update roomId,
      $push: pages: pageId
    pageId
