import {Tracker} from 'meteor/tracker'

import {defineTool} from './defineTool'
import {currentRoom, currentPage} from '../AppState'
import {gridSize} from '../Grid'
import {updateCursor} from '../cursor'
import dom from '../lib/dom'
import storage from '../lib/storage'

export allowTouch = new storage.Variable 'allowTouch', true
export fancyCursor = new storage.Variable 'fancyCursor', #true
  ## Chromium 86 has a bug with SVG cursors causing an annoying offset.
  ## See https://bugs.chromium.org/p/chromium/issues/detail?id=1138488
  not /Chrom(e|ium)\/86\./.test navigator.userAgent
export dark = new storage.Variable 'dark', false

Tracker.autorun ->
  dom.classSet document.body, 'dark', dark.get()

defineTool
  name: 'touch'
  category: 'setting'
  icon: 'hand-pointer'
  help: 'Toggle drawing with touch. Disable when using a pen-enabled device to ignore palm resting on screen; then touch will only work with pan and select tools.'
  active: -> allowTouch.get()
  click: ->
    allowTouch.set not allowTouch.get()

defineTool
  name: 'crosshair'
  category: 'setting'
  icon: 'plus'
  help: 'Use crosshair mouse cursor instead of tool-specific mouse cursor. Easier to aim precisely, and works around a Chrome bug.'
  active: -> not fancyCursor.get()
  init: ->
    Tracker.autorun ->
      fancyCursor.get()
      updateCursor()
  click: ->
    fancyCursor.set not fancyCursor.get()

defineTool
  name: 'dark'
  category: 'setting'
  icon: 'moon'
  help: 'Toggle dark mode (just for you), which flips dark and light colors.'
  active: -> dark.get()
  init: ->
    Tracker.autorun ->
      dom.classSet document.body, 'dark', dark.get()
      updateCursor()
  click: ->
    dark.set not dark.get()

defineTool
  name: 'grid'
  category: 'setting'
  icon: 'grid'
  help: 'Toggle grid/graph paper'
  active: -> currentPage.get()?.data()?.grid
  click: ->
    Meteor.call 'gridToggle', currentPage.get().id

defineTool
  name: 'gridSnap'
  category: 'setting'
  icon: 'grid-snap'
  help: 'Toggle snapping to grid (except pen tool)'
  hotkey: '#'
  active: -> currentRoom.get()?.gridSnap.get()
  click: ->
    return unless (room = currentRoom.get())?
    room.gridSnap.set not room.gridSnap.get()

export snapPoint = (pt) ->
  if currentRoom.get()?.gridSnap.get()
    pt.x = gridSize * Math.round pt.x / gridSize
    pt.y = gridSize * Math.round pt.y / gridSize
  pt
