## Deleting pages is reversible.  Pages are only taken out of the room's page
## list; their objects and history stay in the database.  This module deletes
## pages, runs the Undo Delete and Redo Delete buttons (which are separate from
## the normal Undo/Redo) on the room's history of deletions, which is the same
## for everyone in the room and is kept on the server (see /lib/pages.coffee and
## /lib/pageHistory.coffee), and shows the prompt offering to bring back pages
## that someone else deleted.  It also places and removes page locks (a locked
## page is never deleted, see /lib/pageLocks.coffee) and shows the message that
## pages were not deleted because they are locked.  Both messages come and go in
## the same way (see `Notice`).

import {createEffect, createMemo, createRoot, createSignal, on as on_, onCleanup, Show, untrack} from 'solid-js'
import {Random} from 'meteor/random'
import {createTracker} from 'solid-meteor-data'

import {currentPage, currentRoom, gotoPageId} from './AppState'
import {defaultGrid, defaultGridType} from './Grid'
import storage from './lib/storage'
import {StorageSet} from './lib/storageSet'
import {validId} from '/lib/id'
import {deletionKinds, historyChoices, lockedText, noticeFor, noticeText, topOf} from '/lib/pageHistory'
import {lockOwner, splitLocked, validLockKey} from '/lib/pageLocks'

## Identifies this browser (all its tabs), to not ask it about its own deletions
export browserId = null
try
  browserId = window.localStorage.getItem 'browserId'
unless validId browserId
  browserId = Random.id()
  try
    window.localStorage.setItem 'browserId', browserId

## The secret keys that prove that page locks are this browser's.  A lock can
## only be removed with the key that placed it, so a key must never be lost, and
## every tab must be able to use every key.  Normally the browser has one key,
## saved in localStorage.  Tabs that open at the same moment, before any key is
## saved, can each make one; each saves its own key under its own name, so none
## is overwritten, and the tabs learn each other's keys from storage.  All the
## keys count as this browser: a lock is removed with every key that the browser
## has (see `setPageLock`), and `lockHolders` lists the owners that they give.
## Only owners are ever shown to the room, and the server works out the same
## owner from a key when it is sent to place or remove a lock (see
## /lib/pageLocks.coffee).
lockKeyEntry = 'lockKey'  # the name of a saved key: this, or this and a dot and more

isLockKeyEntry = (name) ->
  name == lockKeyEntry or (typeof name == 'string' and name.startsWith "#{lockKeyEntry}.")

## The keys saved in this browser, in order
savedLockKeys = ->
  found = []
  try
    for index in [0...window.localStorage.length]
      entry = window.localStorage.key index
      continue unless isLockKeyEntry entry
      saved = window.localStorage.getItem entry
      found.push saved if validLockKey(saved) and saved not in found
  found.sort()

lockKeys = savedLockKeys()
unless lockKeys.length
  lockKeys = [Random.secret()]
  try
    window.localStorage.setItem "#{lockKeyEntry}.#{lockOwner(lockKeys[0]).slice 0, 16}", lockKeys[0]
[ownersOfLocks, setOwnersOfLocks] = createSignal lockKeys.map lockOwner
## The owners of this browser's locks: what `by` is in the locks that it placed.
## Reactive, because tabs learn keys while they are open.
export lockHolders = ownersOfLocks

## Learn the keys that other tabs have saved.  A key that this tab knows is never
## forgotten, even if it is no longer saved.
export learnLockKeys = ->
  learned = (saved for saved in savedLockKeys() when saved not in lockKeys)
  return unless learned.length
  lockKeys = lockKeys.concat(learned).sort()
  setOwnersOfLocks lockKeys.map lockOwner
  return

window.addEventListener 'storage', (e) ->
  learnLockKeys() if isLockKeyEntry e.key
## A tab that was still loading when another tab saved a key may not be sent the
## `storage` event, so a tab also looks again when the person comes back to it
window.addEventListener 'focus', -> learnLockKeys()
document.addEventListener 'visibilitychange', -> learnLockKeys() unless document.hidden

## Deletions that this browser has already answered about in each room, as a
## set of deletion IDs, saved one by one (see ./lib/storageSet).  `seen` is
## `null` until the room is first opened in this browser, when nothing counts
## as new.
acks = {}
getAck = (roomId) ->
  acks[roomId] ?=
    seen: new storage.Variable "#{roomId}.deletionsSeen", null
    answered: new StorageSet "#{roomId}.deletionsAnswered.", (item, id) -> item == id
addAnswered = (roomId, deletionIds) ->
  {answered} = getAck roomId
  answered.load()
  for id in deletionIds when not answered.has id
    answered.put id, id
  return

## The deletions of the room that the history may refer to.  Reactive.
deletionsOf = (roomId) ->
  PageDeletions.find(room: roomId).fetch()

## Go to a page, wait until it is displayed, and then call `callback`.
## This way, the page being viewed never disappears from under the viewer.
gotoThen = (pageId, callback) ->
  return callback() if currentPage()?.id == pageId
  done = false
  timer = dispose = null
  run = ->
    return if done
    done = true
    clearTimeout timer
    dispose?()
    callback()
  timer = setTimeout run, 1500  # in case navigation never completes
  createRoot (d) ->
    dispose = d
    createEffect -> run() if currentPage()?.id == pageId
  gotoPageId pageId
  return

## The page to show in place of the current page once `ids` are deleted:
## the page that takes its place, or the last page if there is none.
## `undefined` if the current page is not being deleted.
replacementFor = (ids) ->
  pages = currentRoom()?.data()?.pages
  current = currentPage()?.id
  return unless pages? and current? and current in ids
  index = pages.indexOf current
  for page in pages[index+1..] when page not in ids
    return page
  for page in pages[...index] by -1 when page not in ids
    return page
  return

## What a new blank page is made like: like the current page
blankOptions = ->
  data = currentPage()?.data()
  grid: data?.grid ? defaultGrid
  gridType: data?.gridType ? defaultGridType

## The message that pages were not deleted because they are locked, while it is
## shown: `{op, numbers}`, where `numbers` are the numbers that the pages had
## when they were asked to be deleted, and `op` stands for that deletion.  It is
## only ever about a deletion made in this tab, never about somebody else's.
[lockNotice, setLockNotice] = createSignal null
latestOp = null

ascending = (a, b) -> a - b

## Show the message that the pages `ids` are locked (the ones of them that are
## in the room and locked), without asking the server for anything.  The
## numbers are the ones the pages have now.
tellLocked = (ids) ->
  room = currentRoom()
  return unless room?
  order = room.data()?.pages ? []
  numbers = (order.indexOf(id) + 1 for id in ids when id in order).sort ascending
  return unless numbers.length
  op = latestOp = {dismissed: false}
  setLockNotice null  # the message of an earlier attempt is not about this one
  setLockNotice {op, numbers}
  return

## Delete `ids`, which are pages of the room that are not locked as far as this
## browser can tell, after going to `target` (if any), so that the page being
## viewed never disappears from under the viewer.  The server adds the deletion
## to the room's history.  `kind` is which of the four ways to delete this is,
## and `redoOf` the deletion that is being redone, if any.  `stays` are the
## pages that the person asked to delete as well, but that are locked, so are
## not asked for.  The server deletes only the pages that are asked for, so
## nothing else is deleted, whatever other people do while the request is on its
## way.  If this deletes every page, the server leaves a new blank page (made
## like the current page) and it is shown.  Locked pages are not deleted (that
## is up to the server): if some of `ids` have been locked since, or `stays` is
## not empty, the person is told so.
removePages = (ids, target, kind, redoOf, stays = []) ->
  room = currentRoom()
  return unless room?
  run = ->
    order = room.data()?.pages ? []
    present = (id for id in order when id in ids)
    return unless present.length
    ## The message about locked pages, from what the browser works out at once
    ## and then (if it differs) from what the server says, unless the person
    ## sent the message away, made another deletion since, or left the room
    op = latestOp = {dismissed: false}
    setLockNotice null  # the message of an earlier deletion is not about this one
    tell = (result) ->
      return if op.dismissed or latestOp != op or currentRoom()?.id != room.id
      lockedIds = Array.from new Set stays.concat(result?.locked ? [])
      numbers = (order.indexOf(id) + 1 for id in lockedIds when id in order).sort ascending
      if numbers.length
        setLockNotice {op, numbers}
      else if lockNotice()?.op == op
        setLockNotice null
    ## The ID of a new blank page is made here, so that the page shown at once is the page the server saves
    options = {blank: Object.assign {id: Random.id()}, blankOptions()}
    options.redoOf = redoOf if redoOf?
    result = Meteor.apply 'pagesDel', [present, browserId, kind, options],
      returnStubValue: true
    , (error, serverResult) ->
      if error?
        console.error "Failed to delete pages on server: #{error}"
      else
        tell serverResult
    tell result
    gotoPageId result.blank if result?.blank
  if target?
    gotoThen target, run
  else
    run()
  return

## Undo deletions, for everyone: bring back their pages that are not in the room
## (see `pagesRestore`).
undoDeletions = (deletionIds) ->
  Meteor.call 'pagesRestore', deletionIds, Date.now(), (error) ->
    if error?
      console.error "Failed to restore pages on server: #{error}"
  return

## What the Undo Delete and Redo Delete buttons would do right now, as
## `{undo, redo}`, each `{id, ask}` (the question to ask) or missing if there is
## nothing to do.  Everyone in the room gets the same answer.  Reactive.
export historyInfo = ->
  room = currentRoom()
  pages = room?.data()?.pages
  return {} unless room? and pages?
  historyChoices room.data(), deletionsOf(room.id), pages

## Delete pages.  `kind` is which of the four choices this is.  If this deletes
## every page, the room is left with a new blank page.  The deletion is added to
## the room's history for Undo Delete.  Only the pages of `ids` that are not
## locked are asked for, so that a page that is unlocked while the request is on
## its way is never deleted: that is not what the person was asked about.  If all
## of them are locked, nothing is sent: the person is told that they are.
export deletePages = (ids, {kind} = {}) ->
  room = currentRoom()
  return unless room?
  {deletable, stays} = splitLocked room.data(), ids
  unless deletable.length
    tellLocked stays
    return
  ## Locked pages stay, so the page being viewed only has to be replaced if it
  ## is going to be deleted
  removePages deletable, replacementFor(deletable), (if kind in deletionKinds then kind else 'current'), undefined, stays
  return

## Undo Delete, for the deletion that was asked about: bring back its pages that
## are missing, next to their old neighbors.  Never deletes any page, and the
## page being viewed stays open.  Does nothing if it is not the latest deletion
## that can be undone any more.
export undoDelete = (id) ->
  return unless currentRoom()?
  undoDeletions [id]

## Redo Delete, for the deletion that was asked about: delete its pages that are
## in the room (never any page added since).  The page being viewed stays open,
## unless it is deleted, when its replacement is shown.  Does nothing if it is
## not the deletion undone last any more.
export redoDelete = (id) ->
  room = currentRoom()
  return unless room?
  deletion = PageDeletions.findOne id
  return unless deletion?.room == room.id and topOf(room.data()?.redo) == id
  pages = room.data()?.pages ? []
  ids = (pageId for pageId in deletion.ids when pageId in pages)
  return unless ids.length
  {deletable, stays} = splitLocked room.data(), ids
  unless deletable.length
    tellLocked stays  # nothing to redo, and nothing is sent
    return
  removePages deletable, replacementFor(deletable), deletion.kind, deletion._id, stays
  return

## Lock the page for this browser, so that nobody (including this browser) can
## delete it, or (`locked` false) remove this browser's lock on it.  The page
## stays locked while any other browser has a lock on it.
export setPageLock = (pageId, locked) ->
  learnLockKeys()
  ## A lock is placed with one key, and removed with every key that the browser
  ## has, so that it goes whichever key placed it
  for key in (if locked then [lockKeys[0]] else lockKeys)
    Meteor.call 'pageLock', pageId, locked, key, (error) ->
      if error?
        console.error "Failed to #{if locked then 'lock' else 'unlock'} page on server: #{error}"
  return

## How long a message stays on the screen when nobody closes it, in milliseconds.
## The question about pages somebody else deleted needs a decision, so it stays
## longer; if it runs out, that is the same as answering No.  The message about
## locked pages only has to be found and read: a second to notice a message at
## the top of the screen and look at it, about four seconds to read a sentence
## of up to 15 words at an easy pace, and a little to spare.
lockNoticeMs = 6000
deletedNoticeMs = 8000

## Call `callback` once `ms` milliseconds have passed while the page is visible.
## The time the browser tab is hidden does not count, so a message that comes
## while the person is in another tab still has all of its time when they come
## back.  Returns a function that cancels it.
afterVisible = (ms, callback) ->
  left = ms
  timer = null
  started = 0
  over = false
  start = ->
    started = Date.now()
    timer = setTimeout finish, left
  pause = ->
    return unless timer?
    clearTimeout timer
    timer = null
    left = Math.max 0, left - (Date.now() - started)
  finish = ->
    timer = null
    cancel()
    callback()
  onVisibility = ->
    if document.hidden
      pause()
    else unless timer? or over
      start()
  cancel = ->
    over = true
    clearTimeout timer
    timer = null
    document.removeEventListener 'visibilitychange', onVisibility
  document.addEventListener 'visibilitychange', onVisibility
  start() unless document.hidden
  cancel

## A message at the top of the screen (see `.pageNotices` in main.styl), which
## shows what `props.item()` is, and nothing when that is `null`.
##
## * It slides down from the top when it comes and back up when it goes, and
##   whatever is below it moves along smoothly.  (It stays in place while it
##   leaves, so the animation can be seen: `shown` is the last message it had.)
## * It closes when its cross is pressed, when a press lands anywhere outside
##   the messages, and when its time (`props.ms`) is up.  A press inside any
##   message does nothing, except on that message's own buttons.  The messages
##   are one area: closing or pressing one does not close the other.  Closing
##   is up to `props.onClose()`, which makes `props.item()` `null`.
## * The time runs from when the message appears, only while the page is
##   visible.  `props.keyOf(item)` tells which message it is: the same message
##   updated in place keeps its time, another message in its place starts anew.
## * If its time is up while a press on it is still going on (a click on Yes
##   that began just before), it closes once the press is over, so that the
##   click is not lost.
Notice = (props) ->
  [shown, setShown] = createSignal null
  [leaving, setLeaving] = createSignal false
  slot = null
  timer = null

  createEffect on_ (-> props.item()), (item) ->
    clearTimeout timer
    if item?
      setShown item
      setLeaving false
    else if shown()?
      setLeaving true
      ## Taken out once the animation of main.styl is over (which is at once
      ## when the person asks for no motion).  The animation is looked up a
      ## moment later, so that a message that comes right back, like the one
      ## about locked pages when the person tries again, never leaves at all.
      timer = setTimeout ->
        seconds = if slot? then parseFloat getComputedStyle(slot).animationDuration
        timer = setTimeout ->
          setShown null
          setLeaving false
        , (seconds or 0) * 1000
      , 0
  onCleanup -> clearTimeout timer

  key = createMemo ->
    if (item = props.item())? then props.keyOf item else null

  createEffect ->
    return unless key()?
    pressed = expired = false
    later = null
    close = -> props.onClose()
    cancel = afterVisible props.ms, ->
      if pressed
        expired = true
        later = setTimeout close, 2000  # in case the end of the press is never heard
      else
        close()
    onPointerDown = (e) ->
      if slot?.contains e.target
        pressed = true
      else unless e.target?.closest? '.pageNotices'
        close()
    onPointerEnd = ->
      return unless pressed
      pressed = false
      if expired
        clearTimeout later
        later = setTimeout close, 0  # after the click that the press makes
    document.addEventListener 'pointerdown', onPointerDown, true
    document.addEventListener 'pointerup', onPointerEnd, true
    document.addEventListener 'pointercancel', onPointerEnd, true
    onCleanup ->
      cancel()
      clearTimeout later
      document.removeEventListener 'pointerdown', onPointerDown, true
      document.removeEventListener 'pointerup', onPointerEnd, true
      document.removeEventListener 'pointercancel', onPointerEnd, true

  <Show when={shown()}>
    <div class="pageNotice" classList={leaving: leaving()} ref={(el) -> slot = el}>
      <div class="pageNoticeClip">
        <div class={props.panel} role={props.role}>
          {untrack(-> props.children(shown))}
          <button type="button" class="pageNoticeClose" aria-label="Close this message"
           onClick={-> props.onClose()}>
            <svg viewBox="0 0 10 10" aria-hidden="true">
              <path d="M1.5 1.5L8.5 8.5M8.5 1.5L1.5 8.5"/>
            </svg>
          </button>
        </div>
      </div>
    </div>
  </Show>

## The message that pages were not deleted because they are locked.  It is there
## for the person who tried to delete the pages, not for the other people in the
## room.  Closing it (or letting it run out) also means that a late answer of
## the server does not bring it back.
export LockedNotice = ->
  dismiss = ->
    if (notice = lockNotice())?
      notice.op.dismissed = true
    setLockNotice null
  ## Pages of another room are not these pages, and neither is the answer to
  ## a deletion of the room that was left
  createEffect on_ (-> currentRoom()?.id), ->
    latestOp = null
    setLockNotice null
  , defer: true
  <Notice panel="pageLockNotice" role="alert" item={lockNotice}
   keyOf={(notice) -> notice.op} ms={lockNoticeMs} onClose={dismiss}>
    {(notice) -> <p>{lockedText notice().numbers}</p>}
  </Notice>

## Offer to bring back the pages of the latest deletion of the room, when
## someone else made it, as soon as it happens (if the room is open here) and
## when opening the room later.  Any person can bring the pages back for
## everyone.  Answering "No" only hides the question in this browser: the
## deletion stays in the room's history, to undo with Undo Delete.  Closing the
## question in any other way (its cross, a press outside the messages, or its
## time running out) is answering No, and so is a later deletion that replaces
## it.
export DeletedNotice = ->
  loaded = createTracker ->
    room = currentRoom()
    Boolean room? and not room.loading() and room.data()?.pages?

  ## The first time a room is open in this browser, nothing is new.
  createEffect ->
    return unless loaded()
    roomId = currentRoom().id
    ack = getAck roomId
    return if ack.seen.get()?
    ack.answered.load()
    ids = (deletion._id for deletion in deletionsOf roomId)
    latest = currentRoom().data().latest
    ids.push latest if latest? and latest not in ids
    for id in ids when not ack.answered.has id
      ack.answered.put id, id
    ack.seen.set true

  ## The latest deletion of the room, if this browser did not make it and has
  ## not answered about it
  info = createTracker ->
    return unless loaded()
    room = currentRoom()
    ack = getAck room.id
    return unless ack.seen.get()?
    notice = noticeFor room.data(), deletionsOf(room.id), room.data().pages,
      browserId: browserId
      answered: (id) -> ack.answered.has id
    return unless notice?
    Object.assign {room: room.id}, notice

  bringBack = ->
    return unless (state = info())?
    undoDeletions state.ids
    addAnswered state.room, state.ids
  dismiss = ->
    return unless (state = info())?
    addAnswered state.room, state.ids

  <Notice panel="pageDelNotice" role="alertdialog" item={info}
   keyOf={(state) -> state.ids[0]} ms={deletedNoticeMs} onClose={dismiss}>
    {(state) ->
      <>
        <p>{noticeText state().numbers}</p>
        <div class="pageDelButtons">
          <button type="button" onClick={bringBack}>Yes</button>
          <button type="button" onClick={dismiss}>No</button>
        </div>
      </>
    }
  </Notice>
