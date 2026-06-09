import {createRenderEffect, createSignal, Show} from 'solid-js'
import {useNavigate, useParams} from 'solid-app-router'

## Visiting /clone/:roomId duplicates that room/board into a fresh room and
## redirects to it.  Useful for handing out a link that gives each visitor
## their own independent copy of a board to work on.
export CloneRoom = ->
  [error, setError] = createSignal()
  navigate = useNavigate()
  params = useParams()
  createRenderEffect ->
    Meteor.call 'roomDup', params.roomId, (err, roomId) ->
      if err?
        setError err
        console.error "Failed to clone room on server: #{err}"
      else
        navigate "/r/#{roomId}", replace: true

  ### don't render anything while redirecting ###
  <Show when={error()}>
    <div class="modal error">
      <h1>Failed to Clone Board</h1>
      <p>Perhaps the board link is wrong, or you're disconnected from the network?</p>
      <pre>{error().toString()}</pre>
      <p><a href={Meteor.absoluteUrl()}>Create a new blank board instead</a></p>
    </div>
  </Show>
