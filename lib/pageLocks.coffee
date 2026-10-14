## Page locks, worked out from a room's document.  (The rules are explained in
## /lib/pages.coffee.)  Nothing here touches the database or the screen, so it
## can run (and be tested) anywhere.
##
## A room's `locks` is a list of `{page, by}`: one lock for each browser that
## has locked a page (the same one for all the tabs of a browser).  A page is
## locked while at least one lock refers to it.
##
## `by` is the owner of the lock: not the browser's ID, which is public, but the
## SHA-256 of a secret key that the browser keeps to itself (see `lockOwner`).
## Everyone in the room sees the owners of the locks, and nobody can work out
## the key from an owner, so only the browser with the key can name the owner
## and so remove the lock.  A browser normally has one key; if tabs that opened
## at the same moment each made one, it has more, and all of its keys, and so
## all of its owners, count as the same browser.

import {sha256} from './sha256'

## What a lock key looks like: the characters of `Random.secret()`, 32 or more
export validLockKey = (key) ->
  typeof key == 'string' and /^[A-Za-z0-9_-]{32,128}$/.test key

## The owner (the `by` of locks) of the browser that has the secret key `key`
export lockOwner = (key) -> sha256 key

## The IDs of the pages that are locked, as a `Set`
export lockedPages = (room) ->
  new Set (lock.page for lock in room?.locks ? [])

## The owners `holders` (one owner, or a list of them) as a list
holdersList = (holders) ->
  if Array.isArray holders then holders else [holders]

## Whether any of the owners `holders` (one owner, or a list of them) has a lock
## on the page
export holdsLock = (room, pageId, holders) ->
  mine = holdersList holders
  (room?.locks ? []).some (lock) -> lock.page == pageId and lock.by in mine

## How many owners (browsers) have a lock on the page
export lockCount = (room, pageId) ->
  holders = new Set
  for lock in room?.locks ? [] when lock.page == pageId
    holders.add lock.by
  holders.size

## Who has locked a page, from the point of view of the browser whose owners are
## `holders` (one owner, or a list of them): how many browsers have a lock on it,
## whether this browser is one of them, and how many others are.  All the owners
## of this browser count as one.
export lockSummary = (room, pageId, holders) ->
  mine = holdersList holders
  owners = new Set
  for lock in room?.locks ? [] when lock.page == pageId
    owners.add lock.by
  others = 0
  held = false
  owners.forEach (owner) ->
    if owner in mine then held = true else others += 1
  {count: others + (if held then 1 else 0), mine: held, others}

## Split page IDs into the ones that a deletion can delete and the ones that are
## locked and stay, each in the order given
export splitLocked = (room, ids) ->
  locked = lockedPages room
  deletable: (id for id in ids when not locked.has id)
  stays: (id for id in ids when locked.has id)
