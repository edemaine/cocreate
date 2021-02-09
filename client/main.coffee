import React from 'react'
import {render} from 'react-dom'

import '../lib/main'
import './lib/polyfill'
import './tools/tools'
import dom from './lib/dom'
import {App} from './App'
import {name} from './Name'
import {dark} from './tools/settings'

Meteor.startup ->
  render <App/>, document.getElementById 'react-root'

  ## Coop protocol
  dom.listen window,
    message: (e) ->
      return unless e.data?.coop
      if typeof e.data.user?.fullName == 'string'
        name.setTemp e.data.user.fullName
      if typeof e.data.theme?.dark == 'boolean'
        dark.setTemp e.data.theme.dark
  ## window.opener can be null, but window.parent defaults to window
  parent = window.opener ? window.parent
  if parent? and parent != window
    parent.postMessage
      coop: 1
      status: 'ready'
    , '*'

## Cocreate doesn't perform great in combination with Meteor DevTools;
## prevent it from applying its hooks.
window.__devtools = true
