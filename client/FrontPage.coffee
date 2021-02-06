import React, {useLayoutEffect, useState} from 'react'
import {useHistory} from 'react-router-dom'

import {gridDefault} from './Grid'

export FrontPage = React.memo ->
  [error, setError] = useState()
  history = useHistory()
  useLayoutEffect ->
    Meteor.call 'roomNew',
      grid: gridDefault
    , (err, data) ->
      if err?
        setError err
        console.error "Failed to create new room on server: #{error}"
      else
        history.replace "/r/#{data.room}"
  , []

  if error?
    <div className="modal error">
      <h1>Failed to Create Room</h1>
      <p>Perhaps you're disconnected from the network?</p>
      <pre>{error.toString()}</pre>
      <p><a href={Meteor.absoluteUrl()}>Try again to create a new room</a></p>
    </div>
  else
    null  # don't render anything why redirecting

FrontPage.displayName = 'FrontPage'
