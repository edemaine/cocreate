import {Tracker} from 'meteor/tracker'

import {defineTool} from './defineTool'
import {currentRoom, currentPage, currentGrid, currentGridType, currentOpacity} from '../AppState'
import {updateCursor} from '../cursor'
import dom from '../lib/dom'
import storage from '../lib/storage'

export allowTouch = new storage.Variable 'allowTouch', true
export allowTransparency = new storage.Variable 'allowTransparency', false
export allow25Percent = new storage.Variable 'allow25Percent', false
export allow50Percent = new storage.Variable 'allow50Percent', false
export allow75Percent = new storage.Variable 'allow75Percent', false

export fancyCursor = new storage.Variable 'fancyCursor', #true
  ## Chromium 86 has a bug with SVG cursors causing an annoying offset.
  ## See https://bugs.chromium.org/p/chromium/issues/detail?id=1138488
  not /Chrom(e|ium)\/86\./.test navigator.userAgent
export dark = new storage.Variable 'dark', false

Tracker.autorun ->
  dom.classSet document.body, 'dark', dark.get()
  allowTransparency.set false
  currentOpacity.set 1.0

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
  name: 'gridSquare'
  category: 'setting'
  icon: 'grid'
  help: 'Toggle square grid/graph paper'
  active: ->
    currentGrid() and currentGridType() == 'square'
  click: ->
    Meteor.call 'gridToggle', currentPage.get().id, 'square'

defineTool
  name: 'gridTriangle'
  category: 'setting'
  icon: 'grid-tri'
  help: 'Toggle triangular grid paper'
  active: ->
    currentGrid() and currentGridType() == 'triangle'
  click: ->
    Meteor.call 'gridToggle', currentPage.get().id, 'triangle'

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

defineTool
  name: 'Transparency'
  category: 'color'
  icon: 'highlighter'
  help: 'Change transparency of pen'
  active: ->
    allowTransparency.get()
  click: ->
    allowTransparency.set not allowTransparency.get()
    if allowTransparency.curValue == true
      for el in document.querySelectorAll('[data-tool^="Opacity"]')
        el.style.display = 'block'
        updateOpacity 1.0
        allowTransparency.set true
    else
      for el in document.querySelectorAll('[data-tool^="Opacity"]')
        el.style.display = 'none'
        updateOpacityIcons 1.0
        allowTransparency.set false
  init: ->
    for el in document.querySelectorAll('[data-tool^="Opacity"]')
      el.style.display = 'none'
      currentOpacity.set 1.0

updateOpacity = (val) ->
    allow25Percent.set false
    allow50Percent.set false
    allow75Percent.set false
    if currentOpacity.get() == val
      currentOpacity.set 1.0
    else
      currentOpacity.set val

# These values are chosen for no particular reason.  I saw that
# 12.5 was a number you liked for highlighting Perhaps .25 should be 12.5
for opacity in [.75, .50, .25]
  do (opacity) ->
    defineTool
      name: "Opacity:#{opacity*100}"
      category: 'color'
      icon: "opacity#{opacity*100}"
      help: "Select #{opacity*100}% Transparency"
      click: ->
        updateOpacity opacity
        allow50Percent.set not allow50Percent.get()
      active: ->
        if currentOpacity.get() == opacity then true else false
