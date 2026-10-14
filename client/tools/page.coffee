import {createEffect, createSignal, Index, on as on_, onCleanup, Show} from 'solid-js'
import {Portal} from 'solid-js/web'

import {createTracker} from 'solid-meteor-data'

import {defineTool} from './defineTool'
import {currentRoom, currentPage, currentPageId, gotoPageId} from '../AppState'
import {defaultGrid, defaultGridType} from '../Grid'
import {deletePages, historyInfo, learnLockKeys, lockHolders, redoDelete, setPageLock, undoDelete} from '../PageTrash'
import {Icon, modIcon, trashPath} from '../lib/icons'
import {deletePlan} from '/lib/pageHistory'
import {lockedPages, lockSummary} from '/lib/pageLocks'

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

## Delete Pages tool: a dropdown menu below the button, then a confirmation
## dialog in the middle of the screen.  The menu has the four ways to delete,
## and Undo Delete and Redo Delete for the room's history of deletions, which
## everyone in the room shares (see ../PageTrash.coffee), and which are separate
## from the normal Undo/Redo.

[menu, setMenu] = createSignal null     # {left, top} while dropdown is open
[pending, setPending] = createSignal null  # what awaits confirmation:
  # {action: 'delete', kind} (one of the four choices), or {action: 'undo'}
  # or {action: 'redo'}.  What it asks and does is worked out from the room as
  # it is at that moment (see `dialog` below), not when the choice was made.

closeMenu = -> setMenu null
cancelDelete = -> setPending null

## Close the confirmation dialog.  When that is done with the keyboard, the
## buttons the focus was on go away with the dialog, so hand it to the Delete
## Pages tool in the toolbar, to keep the keyboard user's place.  (Toolbar tools
## are not in the tab order, so it takes `tabindex="-1"` to be focusable by
## script.  Mouse users don't need this: a focused tool would just show its
## tooltip.)
closeDialog = (byKeyboard) ->
  hadFocus = document.activeElement?.closest? '.pageDelDialog'
  cancelDelete()
  if byKeyboard and hadFocus
    if (button = document.querySelector '[data-tool="pageDel"]')?
      button.tabIndex = -1 unless button.hasAttribute 'tabindex'
      button.focus()
  return

menuWidth = 256  # 16em; keep in sync with `.pageDelMenu` in main.styl

openMenu = ->
  button = document.querySelector '[data-tool="pageDel"]'
  return unless (rect = button?.getBoundingClientRect())?
  setMenu
    left: Math.max 8, Math.min rect.left, window.innerWidth - menuWidth - 8
    top: rect.bottom + 4

## The delete choices for the current page, with the pages each would be for
## (`ids`) and the ones it would really delete (`deletable`: locked pages stay,
## see /lib/pageLocks.coffee), and the question to ask.  Pages are not deleted
## in the room's list order only: they need not be next to each other.
deleteChoices = ->
  room = currentRoom()
  data = room?.data()
  pages = data?.pages
  index = room?.pageIndex currentPage()
  return [] unless pages? and index?
  locked = lockedPages data
  n = pages.length
  choice = (fields) ->
    plan = deletePlan fields.ids, pages, locked
    Object.assign fields,
      deletable: plan.deletable
      ask: plan.ask
  [
    choice
      kind: 'current'
      label: 'Delete Current Page'
      ids: [pages[index]]
  ,
    choice
      kind: 'left'
      label: 'Delete All Pages to Left'
      ids: pages[...index]
      disabled: index <= 0
      note: 'No pages to the left.'
  ,
    choice
      kind: 'right'
      label: 'Delete All Pages to Right'
      ids: pages[index+1..]
      disabled: index >= n - 1
      note: 'No pages to the right.'
  ,
    choice
      kind: 'all'
      label: 'Delete All Pages'
      ids: pages
  ]

## Delete choice icons: a trash can with a small overlay at its bottom right
## (a page, or "All") and, for left/right, a curved arrow at its top left/right.
## All four share the same trash can position, so they have the same footprint.
DeleteIcon = (props) ->
  <svg class="delIcon" viewBox="0 1 29 29" aria-hidden="true">
    <path class="base" d={trashPath}
     transform="translate(3.2 7.4) scale(0.042)"/>
    {switch props.kind
      when 'all'
        <>
          <text class="halo" x="15.6" y="28.9" textLength="11.8" lengthAdjust="spacingAndGlyphs">All</text>
          <text class="txt" x="15.6" y="28.9" textLength="11.8" lengthAdjust="spacingAndGlyphs">All</text>
        </>
      else
        <>
          <path class="halo" d="M16.8 15.6H23.8L27.2 19V28.9H16.8z"/>
          <path class="sheet" d="M16.8 15.6H23.8L27.2 19V28.9H16.8z"/>
          <path class="line" d="M23.8 15.6V19H27.2"/>
          {if props.kind == 'left'
            <>
              <path class="halo" d="M11.2 13.2C11.2 8.6 9.4 5.6 6.2 5.6"/>
              <path class="halo fill" d="M1.2 5.6L6.6 2.2V9z"/>
              <path class="arc" d="M11.2 13.2C11.2 8.6 9.4 5.6 6.2 5.6"/>
              <path class="head" d="M1.2 5.6L6.6 2.2V9z"/>
            </>
          else if props.kind == 'right'
            <>
              <path class="halo" d="M16.8 13.2C16.8 8.6 18.6 5.6 21.8 5.6"/>
              <path class="halo fill" d="M27.2 5.6L21.8 2.2V9z"/>
              <path class="arc" d="M16.8 13.2C16.8 8.6 18.6 5.6 21.8 5.6"/>
              <path class="head" d="M27.2 5.6L21.8 2.2V9z"/>
            </>
          }
        </>
    }
  </svg>

## After a press on the board that only closed the menu, ignore its release too,
## so that tools like Text don't act on a release without a press.
swallowRelease = (pointerId) ->
  done = (e) ->
    return unless e.pointerId == pointerId
    document.removeEventListener 'pointerup', done, true
    document.removeEventListener 'pointercancel', done, true
    e.stopPropagation()
  document.addEventListener 'pointerup', done, true
  document.addEventListener 'pointercancel', done, true
  return

## Don't let clicks inside our popups reach the toolbar button, because Solid
## sends events from <Portal>s on to the parent, where they'd toggle the menu.
stop = (e) -> e.stopPropagation()

DeleteOverlays = ->
  ## Close everything when the page changes, or when the tool goes away.
  createEffect on_ currentPageId, ->
    closeMenu()
    cancelDelete()
  , defer: true
  onCleanup ->
    closeMenu()
    cancelDelete()

  ## While a popup is open, close on outside click or Escape, and keep the
  ## board's hotkeys (e.g. Delete or Ctrl-Z) from acting behind it.
  createEffect ->
    return unless menu() or pending()
    onPointerDown = (e) ->
      return unless menu()
      return if e.target?.closest? '.pageDelMenu, [data-tool="pageDel"]'
      closeMenu()
      ## Dismissing the menu by clicking on the board shouldn't also draw.
      if e.target?.closest? '.board'
        e.preventDefault()
        e.stopPropagation()
        swallowRelease e.pointerId
    ## Keys pressed while a popup is open belong to it, so the board never sees
    ## them.  Key releases are not blocked: the board only uses one to end a
    ## Space pan that began earlier, and it ignores any other.  Blocking them
    ## would leave the Pan tool stuck when Space is released with a popup open,
    ## because holding Space keeps sending repeated key presses to the popup.
    onKeyDown = (e) ->
      e.stopPropagation()
      ## WebKit on GTK reports Shift+Tab as the key "Unidentified", but its
      ## `code` is still "Tab"
      switch (if e.code == 'Tab' then 'Tab' else e.key)
        when 'Escape'
          e.preventDefault()
          if pending() then closeDialog true else closeMenu()
        when 'Tab'
          ## Keep the keyboard focus inside the confirmation dialog
          return unless pending()
          buttons = Array.from document.querySelectorAll '.pageDelDialog button'
          return unless buttons.length
          at = buttons.indexOf document.activeElement
          if e.shiftKey and at <= 0
            e.preventDefault()
            buttons[buttons.length - 1].focus()
          else if not e.shiftKey and (at < 0 or at == buttons.length - 1)
            e.preventDefault()
            buttons[0].focus()
        when 'ArrowDown', 'ArrowUp'
          return unless menu()
          e.preventDefault()
          items = Array.from document.querySelectorAll '.pageDelOption:not(:disabled), .pageDelHist:not(:disabled)'
          return unless items.length
          step = if e.key == 'ArrowDown' then 1 else -1
          current = items.indexOf document.activeElement
          next =
            if current < 0
              if step > 0 then 0 else items.length - 1
            else
              (current + step + items.length) % items.length
          items[next].focus()
    document.addEventListener 'pointerdown', onPointerDown, true
    window.addEventListener 'keydown', onKeyDown, true
    window.addEventListener 'resize', closeMenu
    onCleanup ->
      document.removeEventListener 'pointerdown', onPointerDown, true
      window.removeEventListener 'keydown', onKeyDown, true
      window.removeEventListener 'resize', closeMenu

  ## The four delete choices, and what the Undo Delete and Redo Delete buttons
  ## would do.  Both follow the room while the menu is open: pages can be added,
  ## deleted, or brought back by anyone at any time.
  choices = createTracker -> deleteChoices()
  hist = createTracker -> historyInfo()

  ## What the confirmation dialog asks, and what its button does.  This is
  ## worked out from the room as it is right now, so that the question always
  ## matches what the button does, even if someone changes the pages while the
  ## dialog is open.  When there is nothing left to do (e.g. someone else
  ## already deleted those pages), it says so and loses its action button; it
  ## stays open so that it doesn't vanish from under the pointer.
  nothingToDo = text: 'The pages have changed, so there is nothing left to do.'
  dialog = createTracker ->
    return unless (asked = pending())?
    switch asked.action
      when 'delete'
        choice = choices().find (c) -> c.kind == asked.kind
        return nothingToDo if not choice? or choice.disabled
        ## Locked since the choice was made: nothing to confirm, only to tell
        return text: choice.ask unless choice.deletable.length
        text: "#{choice.ask} You can reverse this with Undo Delete."
        label: 'Delete'
        danger: true
        run: -> deletePages choice.ids, kind: choice.kind
      when 'undo'
        return nothingToDo unless (info = hist().undo)?
        text: info.ask
        label: 'Undo Delete'
        run: -> undoDelete info.id
      when 'redo'
        return nothingToDo unless (info = hist().redo)?
        return text: info.ask unless info.deletes  # all locked now
        text: info.ask
        label: 'Redo Delete'
        danger: true
        run: -> redoDelete info.id
  ## If the action button goes away, keep the keyboard focus in the dialog
  createEffect on_ (-> dialog()?.run?), (hasAction) ->
    return if hasAction or not pending()
    return unless (box = document.querySelector '.pageDelDialog')?
    box.querySelector('button')?.focus() unless box.contains document.activeElement
  , defer: true

  choose = (kind) -> (e) ->
    e.stopPropagation()
    choice = choices().find (c) -> c.kind == kind
    return if not choice? or choice.disabled
    closeMenu()
    if choice.deletable.length
      setPending {action: 'delete', kind}
    else
      ## Every page it is for is locked: nothing to confirm.  Deleting them
      ## deletes nothing and tells the person which pages are locked.
      deletePages choice.ids, kind: choice.kind
  chooseHist = (action) -> (e) ->
    e.stopPropagation()
    return unless (info = hist()[action])?
    closeMenu()
    if action == 'redo' and not info.deletes
      redoDelete info.id  # every page it is for is locked: only tells so
    else
      setPending {action}
  confirm = (e) ->
    e.stopPropagation()
    chosen = dialog()
    closeDialog e.detail == 0  # a keyboard "click" has no click count
    chosen?.run?()
  cancel = (e) ->
    e.stopPropagation()
    closeDialog e.detail == 0
  focusLater = (el) -> setTimeout (-> el.focus()), 0

  <>
    <Show when={menu()}>
      <Portal>
        <div class="pageDelMenu" role="menu" onClick={stop}
         style={left: "#{menu()?.left}px", top: "#{menu()?.top}px"}>
          <Index each={choices()}>{(choice) ->
            <button type="button" class="pageDelOption" role="menuitem"
             disabled={choice().disabled} onClick={(e) -> choose(choice().kind) e}>
              <DeleteIcon kind={choice().kind}/>
              <span>
                {choice().label}
                <Show when={choice().disabled}>
                  <small>{choice().note}</small>
                </Show>
              </span>
            </button>
          }</Index>
          <div class="pageDelHistory">
            <button type="button" class="pageDelHist" role="menuitem"
             disabled={!hist().undo} onClick={chooseHist 'undo'}
             title={hist().undo?.ask ? 'No deletions to undo'}>
              <Icon class="histIcon" icon="undo" fill="currentColor"/>
              <span>Undo Delete</span>
            </button>
            <button type="button" class="pageDelHist" role="menuitem"
             disabled={!hist().redo} onClick={chooseHist 'redo'}
             title={hist().redo?.ask ? 'No deletions to redo'}>
              <Icon class="histIcon" icon="redo" fill="currentColor"/>
              <span>Redo Delete</span>
            </button>
          </div>
        </div>
      </Portal>
    </Show>
    <Show when={pending()}>
      <Portal>
        <div class="pageDelVeil" onClick={cancel}>
          <div class="pageDelDialog" role="alertdialog" aria-modal="true" onClick={stop}>
            <p>{dialog()?.text}</p>
            <div class="pageDelButtons">
              <button type="button" ref={focusLater} onClick={cancel}>
                {if dialog()?.run then 'Cancel' else 'Close'}
              </button>
              <Show when={dialog()?.run}>
                <button type="button" classList={danger: dialog()?.danger}
                 onClick={confirm}>
                  {dialog()?.label}
                </button>
              </Show>
            </div>
          </div>
        </div>
      </Portal>
    </Show>
  </>

defineTool
  name: 'pageDel'
  category: 'page'
  icon: 'trash-alt'
  help: 'Delete pages: current, left, right, or all. Undo Delete and Redo Delete are in this menu'
  active: -> menu()?
  click: ->
    if menu()
      closeMenu()
    else
      cancelDelete()
      openMenu()
  portal: -> <DeleteOverlays/>

## Lock Page: the current page cannot be deleted by anyone (including you)
## while any user has a lock on it.  Everyone in the room sees the locks, and
## each user can only remove their own lock.  The button shows a closed padlock
## while the current page is locked by anybody, and is pressed while this
## browser has a lock on it.
lockHere = ->
  pageId = currentPage()?.id
  if pageId?
    lockSummary currentRoom()?.data(), pageId, lockHolders()
  else
    {count: 0, mine: false, others: 0}
holdsHere = -> lockHere().mine

users = (n) -> "#{n} #{if n == 1 then 'user' else 'users'}"
lockHelp = ->
  {count, mine, others} = lockHere()
  if not count
    'Lock the current page so that nobody, including you, can delete it. Only you can remove your lock'
  else if mine and not others
    'You have locked this page, so nobody can delete it. Click to remove your lock'
  else if mine
    "You and #{if others == 1 then 'another user' else "#{others} other users"} have locked this page. Click to remove your lock: the page stays locked while the others keep theirs"
  else
    "This page is locked by #{users count}. Only they can remove their lock. Click to lock it as well, so that it stays locked when they unlock"

defineTool
  name: 'pageLock'
  category: 'page'
  icon: -> modIcon (if lockHere().count then 'lock' else 'lock-open'), fill: 'currentColor'
  help: lockHelp
  active: holdsHere
  click: ->
    pageId = currentPage()?.id
    return unless pageId?
    learnLockKeys()  # whether this browser holds the lock depends on all its keys
    setPageLock pageId, not holdsHere()
