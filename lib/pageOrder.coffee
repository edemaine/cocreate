## Where deleted pages go back when they are restored.
## This file has no imports, so it can run (and be tested) anywhere.

###
Where pages go back when a deletion is undone.  `pages` is the room's current
list of page IDs, `order` is the room's list right before that deletion, and
`ids` are the pages that deletion removed.  Pages are never identified by
number, only by who their neighbors were, so any changes since then (pages
added, deleted, or restored) don't matter.

Each missing page goes
1. right after the nearest earlier page (in `order`) that is in the list now,
   which includes pages restored a moment ago, so that a block of deleted
   pages comes back as a block; otherwise
2. right before the nearest later page that is in the list now; otherwise
3. at the end.

Pages in `ids` that are in the list already are skipped, and no page is
ever removed.  Returns the new list of pages, and the insertions that produce
it as `{id, pos}` steps to apply in order (`pos` is the index to insert at).
###
export planOrderRestore = (pages, order, ids) ->
  result = pages[..]
  steps = []
  ## Only pages that are in the list or being restored can be anchors.
  relevant = new Set pages.concat ids
  order = (id for id in order when relevant.has id)
  at = new Map
  at.set id, i for id, i in order
  missing = []
  for id in ids when id not in result and id not in missing
    missing.push id
  fallback = order.length
  missing.sort (a, b) -> (at.get(a) ? fallback) - (at.get(b) ? fallback)
  for id in missing
    pos = null
    if (i = at.get id)?
      j = i - 1
      while j >= 0 and not pos?
        k = result.indexOf order[j]
        pos = k + 1 if k >= 0
        j--
      j = i + 1
      while j < order.length and not pos?
        k = result.indexOf order[j]
        pos = k if k >= 0
        j++
    pos ?= result.length
    result.splice pos, 0, id
    steps.push {id, pos}
  {pages: result, steps}

###
The page to show when the page that was at `index` in `old` (the room's list of
pages when it was last seen) is no longer in `pages` (the room's list now, which
must not be empty), no matter how many pages were removed with it: the next
page after it that is still there, else the nearest one before it.
###
export pageAfterRemoval = (old, index, pages) ->
  for id in old[index+1..] when id in pages
    return id
  for id in old[...index] by -1 when id in pages
    return id
  pages[Math.min index, pages.length - 1]
