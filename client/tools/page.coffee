import {defineTool} from './defineTool'
import {currentRoom} from '../DrawApp'
import {gridDefault} from '../Grid'

defineTool
  name: 'pagePrev'
  category: 'page'
  icon: 'chevron-left-square'
  help: 'Go to previous page'
  hotkey: 'Page Up'
  click: -> currentRoom.get().pageChangeDelta -1

defineTool
  name: 'pageNext'
  category: 'page'
  icon: 'chevron-right-square'
  help: 'Go to next page'
  hotkey: 'Page Down'
  click: -> currentRoom.get().pageChangeDelta +1

defineTool
  name: 'pageNew'
  category: 'page'
  icon: 'plus-square'
  help: 'Add new blank page after the current page'
  click: ->
    index = room?.pageIndex()
    return unless index?
    Meteor.call 'pageNew',
      room: room.id
      grid:
        if room.pageData?
          Boolean room.pageData.grid
        else
          gridDefault
    , index+1
    , (error, page) ->
      if error?
        return console.error "Failed to create new page on server: #{error}"
      room.changePage page

defineTool
  name: 'pageDup'
  category: 'page'
  icon: 'clone'
  help: 'Duplicate current page'
  click: ->
    Meteor.call 'pageDup', room.page, (error, page) ->
      if error?
        return console.error "Failed to duplicate page on server: #{error}"
      room.changePage page
