import {defineTool} from './defineTool'
import {currentRoom, currentPage, setPageId} from '../AppState'
import {defaultGrid, defaultGridType} from '../Grid'

defineTool
  name: 'pagePrev'
  category: 'page'
  icon: 'chevron-left-square'
  help: 'Go to previous page'
  hotkey: 'Page Up'
  click: ->
    pageId = currentRoom.get()?.pageDelta currentPage.get(), -1
    setPageId pageId if pageId?

defineTool
  name: 'pageNext'
  category: 'page'
  icon: 'chevron-right-square'
  help: 'Go to next page'
  hotkey: 'Page Down'
  click: ->
    pageId = currentRoom.get()?.pageDelta currentPage.get(), +1
    setPageId pageId if pageId?

defineTool
  name: 'pageNew'
  category: 'page'
  icon: 'plus-square'
  help: 'Add new blank page after the current page'
  click: ->
    page = currentPage.get()
    return unless page?
    index = currentRoom.get()?.pageIndex page
    return unless index?
    data = page.data()
    Meteor.call 'pageNew',
      room: currentRoom.get().id
      grid: data?.grid ? defaultGrid
      gridType: data?.gridType ? defaultGridType
    , index+1
    , (error, pageId) ->
      if error?
        return console.error "Failed to create new page on server: #{error}"
      setPageId pageId

defineTool
  name: 'pageDup'
  category: 'page'
  icon: 'clone'
  help: 'Duplicate current page'
  click: ->
    Meteor.call 'pageDup', currentPage.get().id, (error, pageId) ->
      if error?
        return console.error "Failed to duplicate page on server: #{error}"
      setPageId pageId
