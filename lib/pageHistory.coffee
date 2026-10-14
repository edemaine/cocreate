## What Undo Delete, Redo Delete, and the "Bring them back?" question do, worked
## out from a room's history of deletions and the room's current list of pages.
## Nothing here touches the database or the screen, so it can run (and be
## tested) anywhere.
##
## The history is the same for everyone in the room and is kept on the server
## (see /lib/pages.coffee).  The room itself holds two stacks of deletion IDs,
## `undo` (deletions that can be undone, the latest last) and `redo` (deletions
## that were undone, the one undone last at the end), and `latest`, the ID of
## the latest deletion made.  Each deletion is one document of `PageDeletions`,
## however many pages it deleted:
##   {_id, room, kind, ids, order, by, at}
## where `kind` is 'current', 'left', 'right', or 'all' (the four ways to
## delete), `ids` are the pages it deleted, and `order` is the room's page list
## right before it, which is how its pages find their way back (see
## `planOrderRestore`: by their neighbors, never by page number).  `by` is the
## browser that made it.  `blank` is the ID of the blank page that the deletion
## added, if it deleted every page.  A deletion never changes once it is in a
## stack.  The pages of a deletion need not be next to each other, and a locked
## page is never one of them (see /lib/pageLocks.coffee): pages that were locked
## when pages were deleted just stayed.

import {planOrderRestore} from './pageOrder'
import {lockedPages} from './pageLocks'

## How many deletions are kept in each stack, in each room
export historyLimit = 40
export deletionKinds = ['current', 'left', 'right', 'all']

## "5", "5 and 8", "1 to 4, 8 and 10"
export listPages = (numbers) ->
  parts = []
  i = 0
  while i < numbers.length
    j = i
    j++ while j + 1 < numbers.length and numbers[j+1] == numbers[j] + 1
    if j - i >= 2
      parts.push "#{numbers[i]} to #{numbers[j]}"
    else
      for k in [i..j]
        parts.push "#{numbers[k]}"
    i = j + 1
  if parts.length <= 1
    parts[0] ? ''
  else
    "#{parts[...-1].join ', '} and #{parts[parts.length - 1]}"

## "Page 3", "Pages 3 and 4", "Pages 1 to 4"
export pagesLabel = (numbers) ->
  if numbers.length == 1
    "Page #{numbers[0]}"
  else
    "Pages #{listPages numbers}"

## The ID at the end of a stack, if there is one
export topOf = (stack) ->
  stack?[stack.length - 1]

## What Undo Delete would do for `deletion`: bring back the pages of the deletion
## that are not in the room now, and the numbers they will have.  `undefined`
## if all of them are back already.
export undoPlan = (deletion, pages) ->
  missing = (id for id in deletion.ids when id not in pages)
  return unless missing.length
  placed = planOrderRestore(pages, deletion.order, missing).pages
  numbers = (placed.indexOf(id) + 1 for id in missing).sort (a, b) -> a - b
  others = pages.some (id) -> id not in deletion.ids
  {deletion, missing, numbers, others}

## "Page 3 has been locked by users in the room.", "Pages 6 and 8 have been
## locked by users in the room."  (For pages that a deletion left alone.)
export lockedText = (numbers) ->
  verb = if numbers.length == 1 then 'has' else 'have'
  "#{pagesLabel numbers} #{verb} been locked by users in the room."

## "Page 6 is locked and will stay.", "Pages 6 and 8 are locked and will stay."
export staysText = (numbers) ->
  verb = if numbers.length == 1 then 'is' else 'are'
  "#{pagesLabel numbers} #{verb} locked and will stay."

## What deleting `ids` (pages of the room, in its order) would do, in the room
## whose list of pages is `pages` and whose locked pages are `locked` (a `Set`):
## `deletable` are the pages that would be deleted, `numbers` the numbers they
## have, `stays` the numbers of the pages that are locked and would stay, and
## `ask` the question to ask.  Deleting every page leaves one blank page, and
## says so, whichever of the four ways to delete it is (deleting the only page
## of the room is that, too).
export deletePlan = (ids, pages, locked) ->
  number = (id) -> pages.indexOf(id) + 1
  ascending = (a, b) -> a - b
  deletable = (id for id in ids when not locked.has id)
  numbers = (number(id) for id in deletable).sort ascending
  stays = (number(id) for id in ids when locked.has id).sort ascending
  ask =
    if not ids.length
      ''
    else if not deletable.length
      lockedText stays
    else if deletable.length == pages.length
      if pages.length == 1
        "Delete Page 1 and leave a blank page?"
      else
        "Delete all #{pages.length} pages and leave one blank page?"
    else if stays.length
      "Delete #{pagesLabel numbers} for everyone? #{staysText stays}"
    else
      "Delete #{pagesLabel numbers} for everyone?"
  {deletable, numbers, stays, ask}

## What Redo Delete would do for `deletion`: delete its pages that are in the
## room and not locked.  `present` are those, `stays` the numbers of the pages
## of the deletion that are in the room and locked, so they stay.  `blank` is
## whether that would leave no page at all, so that a blank page gets added.
export redoPlan = (deletion, pages, locked = new Set) ->
  inRoom = (id for id in deletion.ids when id in pages)
  return unless inRoom.length
  present = (id for id in inRoom when not locked.has id)
  ascending = (a, b) -> a - b
  numbers = (pages.indexOf(id) + 1 for id in present).sort ascending
  stays = (pages.indexOf(id) + 1 for id in inRoom when locked.has id).sort ascending
  {deletion, present, numbers, stays, blank: present.length > 0 and present.length == pages.length}

export undoAsk = ({deletion, missing, numbers, others}) ->
  ## "All" is only for a deletion that deleted every page (and so added a blank
  ## page), not for one that left locked pages
  emptied = deletion.blank?
  all = emptied and missing.length == deletion.ids.length and missing.length > 1
  what = if all then "all #{missing.length} pages" else pagesLabel numbers
  if emptied and others
    "Bring back #{what}? The blank page stays."
  else
    "Bring back #{what}?"

export redoAsk = ({deletion, present, numbers, stays, blank}) ->
  return lockedText stays unless present.length
  all = deletion.kind == 'all' and present.length == deletion.ids.length and present.length > 1
  what = if all then "all #{present.length} pages" else pagesLabel numbers
  ask =
    if blank
      "Delete #{what} again? A blank page will be added."
    else
      "Delete #{what} again?"
  if stays.length
    "#{ask} #{staysText stays}"
  else
    ask

## What the Undo Delete and Redo Delete buttons would do right now, as
## `{undo, redo}`, each `{id, ask}` (the deletion and the question to ask) or
## missing if there is nothing to do.  Undo Delete is always for the latest
## deletion that has not been undone, and Redo Delete for the one undone last:
## `room` is the room's document, `deletions` the room's `PageDeletions`, and
## `pages` its list of pages.  A redo choice has `deletes`, whether it has any
## page that is not locked to delete (if not, it only says that they are locked).
export historyChoices = (room, deletions, pages) ->
  choices = {}
  find = (id) -> deletions.find (deletion) -> deletion._id == id
  if (deletion = find topOf room?.undo)? and (plan = undoPlan deletion, pages)?
    choices.undo = {id: deletion._id, ask: undoAsk plan}
  if (deletion = find topOf room?.redo)? and (plan = redoPlan deletion, pages, lockedPages room)?
    choices.redo = {id: deletion._id, ask: redoAsk(plan), deletes: plan.present.length > 0}
  choices

## The deletion to ask about, if any: only the latest deletion of the room is
## ever asked about, and only if it has not been undone, another browser made it
## (`browserId` is this one), this browser has not answered about it
## (`answered(id)`), and some of its pages are not in the room.  When another
## deletion comes, the question about the one before it is gone for good, as if
## answered No (a deletion that was undone, or one made by this browser, ends
## the question the same way).  Returns its ID in a list, and the numbers that
## its pages will have once they are back.
export noticeFor = (room, deletions, pages, {browserId, answered}) ->
  latestId = room?.latest
  return unless latestId? and topOf(room.undo) == latestId
  latest = deletions.find (deletion) -> deletion._id == latestId
  return unless latest? and latest.by != browserId
  return if answered latestId
  missing = (id for id in latest.ids when id not in pages)
  return unless missing.length
  placed = planOrderRestore(pages, latest.order, missing).pages
  numbers = (placed.indexOf(id) + 1 for id in missing).sort (a, b) -> a - b
  {ids: [latestId], numbers}

export noticeText = (numbers) ->
  if numbers.length == 1
    "Page #{numbers[0]} was deleted. Bring it back?"
  else
    "Pages #{listPages numbers} were deleted. Bring them back?"
