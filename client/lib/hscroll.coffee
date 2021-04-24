## Make scroll wheel automatically scroll horizontally in horizontal palettes

import {useEffect} from 'react'

scrolling = {}
scrollDuration = 250

onWheel = (e) ->
  if Math.abs(e.deltaY) > Math.abs(e.deltaX) and not e.shiftKey
    e.preventDefault()
    elt = e.currentTarget
    delta = e.deltaX or e.deltaY
    switch e.deltaMode
      #when WheelEvent.DOM_DELTA_PIXEL
      when WheelEvent.DOM_DELTA_LINE
        delta *= 50
      when WheelEvent.DOM_DELTA_PAGE
        delta *= elt.clientWidth
    delta /= 2  # this speed factor seems to match shift + scroll wheel
    scrolling[elt.id] ?= {}
    unless scrolling[elt.id].request?
      scrolling[elt.id].origin = scrolling[elt.id].target = elt.scrollLeft
    scrolling[elt.id].target = \
      Math.max 0,
      Math.min elt.scrollWidth - elt.clientWidth,
      scrolling[elt.id].target + delta
    scrolling[elt.id].request ?= window.requestAnimationFrame \
      frame = (ms) -> # eslint-disable-line coffee/no-unused-vars
        scrolling[elt.id].begin ?= ms
        frac = Math.min 1, (ms - scrolling[elt.id].begin) / scrollDuration
        elt.scrollLeft = (1-frac) * scrolling[elt.id].origin +
                          frac * scrolling[elt.id].target
        if frac < 1
          scrolling[elt.id].request = window.requestAnimationFrame frame
        else
          scrolling[elt.id].request = scrolling[elt.id].begin = null

export useHorizontalScroll = (ref) ->
  useEffect ->
    ref.current?.addEventListener 'wheel', onWheel, passive: false
    -> ref.current?.removeEventListener 'wheel', onWheel
  , [ref.current]
