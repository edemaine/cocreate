import {defineTool} from './defineTool'
import {currentRoom, currentPage, gotoPageId} from '../AppState'
import {defaultGrid, defaultGridType} from '../Grid'

defineTool
  name: 'pagePrev'
  category: 'page'
  icon: 'chevron-left-square'
  help: 'Go to previous page'
  hotkey: 'Page Up'
  click: ->
    pageId = currentRoom()?.pageDelta currentPage(), -1
    gotoPageId pageId if pageId?

defineTool
  name: 'pageNext'
  category: 'page'
  icon: 'chevron-right-square'
  help: 'Go to next page'
  hotkey: 'Page Down'
  click: ->
    pageId = currentRoom()?.pageDelta currentPage(), +1
    gotoPageId pageId if pageId?

defineTool
  name: 'pageNew'
  category: 'page'
  icon: 'plus-square'
  help: 'Add new blank page after the current page'
  click: ->
    page = currentPage()
    return unless page?
    index = currentRoom()?.pageIndex page
    return unless index?
    data = page.data()
    Meteor.call 'pageNew',
      room: currentRoom().id
      grid: data?.grid ? defaultGrid
      gridType: data?.gridType ? defaultGridType
    , index+1
    , (error, pageId) ->
      if error?
        return console.error "Failed to create new page on server: #{error}"
      gotoPageId pageId

defineTool
  name: 'pageDup'
  category: 'page'
  icon: 'clone'
  help: 'Duplicate current page'
  click: ->
    Meteor.call 'pageDup', currentPage().id, (error, pageId) ->
      if error?
        return console.error "Failed to duplicate page on server: #{error}"
      gotoPageId pageId
