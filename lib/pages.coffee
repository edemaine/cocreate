import {validId} from './id'
import {checkRoom} from './rooms'

@Pages = new Mongo.Collection 'pages'

export checkPage = (page) ->
  if validId(page) and data = Pages.findOne page
    data
  else
    throw new Error "Invalid page ID #{page}"

Meteor.methods
  pageNew: (page, index) ->
    check page,
      room: String
      grid: Match.Optional Boolean
      bg: Match.Optional Boolean
    check index, Match.Optional Number
    unless @isSimulation
      now = new Date
      page.created = now
    roomId = page.room
    room = checkRoom roomId
    pageId = Pages.insert page, channel: "rooms::#{roomId}::pages"
    Rooms.update roomId,
      $push: pages:
        $each: [pageId]
        $position: index ? room?.pages?.length ? 0
    pageId

  pageDup: (pageId) ->
    check pageId, String
    page = checkPage pageId
    room = checkRoom page.room
    index = room.pages?.indexOf pageId
    unless index? and index >= 0
      throw new Error "Page #{page._id} not found in its room #{room._id}"
    delete page._id
    delete page.created
    newPageId = Meteor.apply 'pageNew', [page, index+1]
    Objects.find
      room: room._id
      page: pageId
    .forEach (obj) ->
      delete obj._id
      delete obj.created
      delete obj.updated
      obj.page = newPageId
      Meteor.call 'objectNew', obj
    newPageId

  gridToggle: (page) ->
    check page, String
    data = checkPage page
    Pages.update page,
      $set: grid: not data.grid
    , channel: "rooms::#{data.room}::pages"

  bgToggle: (page) ->
    check page, String
    data = checkPage page
    Pages.update page,
      $set: bg: not data.bg
    , channel: "rooms::#{data.room}::pages"
