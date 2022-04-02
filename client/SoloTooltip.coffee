## OverlayTrigger wrapper to enforce at most one tooltip visible at once.
## Also provides a `closeTooltip` method to close all tooltips.

import {createSignal, splitProps} from 'solid-js'
import OverlayTrigger from 'solid-bootstrap/esm/OverlayTrigger'

[shown, setShown] = createSignal()

export closeTooltip = ->
  setShown null

export SoloTooltip = (props) ->
  [local, rest] = splitProps props, ['id', 'children']
  unless local.id?
    throw new Error "SoloTooltip missing id prop"
  onToggle = (newShow) ->
    if newShow
      setShown local.id
    else if shown() == local.id
      setShown null
  <OverlayTrigger {...rest} show={shown() == local.id} onToggle={onToggle}>
    {local.children}
  </OverlayTrigger>
