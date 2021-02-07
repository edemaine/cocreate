## OverlayTrigger wrapper to enforce at most one tooltip visible at once.
## Also provides a `closeTooltip` method to close all tooltips.

import React, {useCallback} from 'react'
import OverlayTrigger from 'react-bootstrap/OverlayTrigger'
import {ReactiveVar} from 'meteor/reactive-var'
import {useTracker} from 'meteor/react-meteor-data'

shown = new ReactiveVar

export closeTooltip = ->
  shown.set null

export SoloTooltip = React.memo ({id, children, ...props}) ->
  unless id?
    throw new Error "SoloTooltip missing id prop"
  show = useTracker ->
    shown.get() == id
  , []
  onToggle = useCallback (newShow) ->
    if newShow
      shown.set id
    else if shown.get() == id
      shown.set null
  , [id]
  <OverlayTrigger {...props} show={show} onToggle={onToggle}>
    {children}
  </OverlayTrigger>
SoloTooltip.displayName = 'SoloTooltip'
