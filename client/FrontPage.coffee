import {createRenderEffect, createSignal, Show} from 'solid-js'
import {useNavigate} from 'solid-app-router'

import {defaultGrid, defaultGridType} from './Grid'

export FrontPage = ->
  [error, setError] = createSignal()
  navigate = useNavigate()
  createRenderEffect ->
    Meteor.call 'roomNew',
      grid: defaultGrid
      gridType: defaultGridType
    , (err, data) ->
      if err?
        setError err
        console.error "Failed to create new room on server: #{err}"
      else
        navigate "/r/#{data.room}", replace: true

  ### don't render anything while redirecting ###
  <Show when={error()}>
    <div class="modal error">
      <h1>Failed to Create Room</h1>
      <p>Perhaps you're disconnected from the network?</p>
      <pre>{error().toString()}</pre>
      <p><a href={Meteor.absoluteUrl()}>Try again to create a new room</a></p>
    </div>
  </Show>
