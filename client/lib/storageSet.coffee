import {ReactiveVar} from 'meteor/reactive-var'

###
Set of JSONifiable items, remembered by localStorage and shared with the other
tabs of the browser.  Every item is saved under a key of its own, `prefix`
followed by the item's ID, and `valid(item, id)` tells the items that make sense.

Each tab has its own copy of the set, and is told about the changes of other tabs
only a moment after they happen.  A list saved as a whole, under one key, would
let a tab write back what it knew before and undo what another tab just did (no
browser lets a tab read a key and write it back in one step).  Here a change
replaces nothing but its own item, so tabs that change different items can't
undo each other.  Call `load()` to see the latest of what other tabs saved before
changing an item that they may have changed too.
###
export class StorageSet
  constructor: (@prefix, @valid = -> true) ->
    @items = new Map     # ID -> item, as this tab knows it
    @unsaved = new Set   # IDs of the items that localStorage did not take
    @version = 0
    @changed = new ReactiveVar @version
    @load()
    window.addEventListener 'storage', @listener = (e) =>
      ## (`e.key` is null when all of the storage was cleared)
      @load() if not e.key? or e.key.startsWith @prefix
  stop: ->
    window.removeEventListener 'storage', @listener

  ## Reactive: all the items, the item with this ID, whether there is one.
  all: ->
    @changed.get()
    Array.from @items.values()
  get: (id) ->
    @changed.get()
    @items.get id
  has: (id) ->
    @changed.get()
    @items.has id

  ## Bring this tab's copy up to date with what is saved in this browser.
  load: ->
    stored = new Map
    try
      storage = window.localStorage
      for i in [0...storage.length]
        key = storage.key i
        continue unless key? and key.startsWith @prefix
        id = key[@prefix.length..]
        item = null
        try
          item = JSON.parse storage.getItem key
        continue unless item? and @valid item, id
        stored.set id, item
    catch
      return  # no localStorage: this tab's copy is all there is
    changed = false
    for [id, item] from stored when not @unsaved.has id
      unless JSON.stringify(item) == JSON.stringify @items.get id
        @items.set id, item
        changed = true
    ## Items that another tab removed (but not those that were never saved)
    for id from Array.from @items.keys() when not stored.has(id) and not @unsaved.has id
      @items.delete id
      changed = true
    @touch() if changed
    return

  ## Save `item`, replacing the item with the same ID.  If localStorage takes it
  ## again after refusing something (e.g., it was full), the items it refused
  ## are saved as well.  Returns whether localStorage took `item`.
  put: (id, item) ->
    @items.set id, item
    saved = @save id
    if saved
      @save other for other from Array.from @unsaved
    @touch()
    saved
  ## Save the item with this ID, and note whether localStorage took it.
  save: (id) ->
    return false unless (item = @items.get id)?
    key = @prefix + id
    try
      json = JSON.stringify item
      window.localStorage.setItem key, json
      saved = window.localStorage.getItem(key) == json
    if saved
      @unsaved.delete id
    else
      @unsaved.add id
    Boolean saved
  remove: (id) ->
    @items.delete id
    @unsaved.delete id
    try
      window.localStorage.removeItem @prefix + id
    @touch()
    return

  touch: ->
    @changed.set ++@version
