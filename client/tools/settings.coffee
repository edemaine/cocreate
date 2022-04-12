import {Tracker} from 'meteor/tracker'

import {defineTool} from './defineTool'
import {currentRoom, currentPage, currentGrid, currentGridType} from '../AppState'
import {updateCursor} from '../cursor'
import dom from '../lib/dom'
import storage from '../lib/storage'

storage.upgradeKey 'allowTouch', 'touchDraw'  # backward compatibility
export touchDraw = new storage.Variable 'touchDraw', true
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
  icon: 'touch-draw'
  help: 'Toggle drawing with touch. Disable when using a pen-enabled device to ignore palm resting on screen; then touch will only work with pan and select tools, and multitouch will pan/zoom in drawing modes.'
  active: -> touchDraw.get()
  click: ->
    touchDraw.set not touchDraw.get()

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
  name: 'gridSquare'
  category: 'setting'
  icon: 'grid'
  help: 'Toggle square grid/graph paper'
  active: ->
    currentGrid() and currentGridType() == 'square'
  click: ->
    Meteor.call 'gridToggle', currentPage().id, 'square'

defineTool
  name: 'gridTriangle'
  category: 'setting'
  icon: 'grid-tri'
  help: 'Toggle triangular grid paper'
  active: ->
    currentGrid() and currentGridType() == 'triangle'
  click: ->
    Meteor.call 'gridToggle', currentPage().id, 'triangle'

defineTool
  name: 'gridSnap'
  category: 'setting'
  icon: 'grid-snap'
  help: 'Toggle snapping to grid (except pen tool)'
  hotkey: '#'
  active: -> currentRoom()?.gridSnap.get()
  click: ->
    return unless (room = currentRoom())?
    room.gridSnap.set not room.gridSnap.get()

defineTool
  name: 'gridHalfSnap'
  category: 'setting'
  icon: 'grid-half-snap'
  help: 'Toggle snapping to half-grid positions in addition to grid positions (when grid snapping is turned on)'
  hotkey: '%'
  active: -> currentRoom()?.gridHalfSnap.get()
  click: ->
    return unless (room = currentRoom())?
    room.gridHalfSnap.set not room.gridHalfSnap.get()
