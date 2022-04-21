import {createEffect, createSignal, onCleanup, Show} from 'solid-js'
import {createFindOne} from 'solid-meteor-data'

export ConnectionStatus = ->
  [show, setShow] = createSignal true
  [, status] = createFindOne -> Meteor.status()

  ## Ignore initial connecting status
  [initialized, setInitialized] = createSignal false
  createEffect ->
    setInitialized true if status.status != 'connecting'

  onReconnect = (e) ->
    e.preventDefault()
    Meteor.reconnect()
  toggleShow = (e) ->
    e.preventDefault()
    setShow not show()

  <Show when={initialized() and not status.connected}>{->
    setShow true
    <div classList={
      offline: true
      show: show()
    }>
      <Show when={show()} fallback={
        <>[<a href="#" onClick={toggleShow}>show</a>]</>
      }>
        <h1>Disconnected From Server</h1>
        <p class="small">
          You may be offline, or the server may be restarting.  You can still draw locally, and your changes will hopefully synchronize once reconnected.
        </p>
        <p class="status">
          {switch status.status
            when 'connecting'
              <>Attempting to reconnect…</>
            when 'waiting'
              <>Next reconnection attempt in <Countdown time={status.retryTime}/>…
              </>
            when 'failed'
              <>Permanent failure: {status.reason}</>
            when 'offline'
              <>Offline</>
          }
        </p>
        <div>
          [<a href="#" onClick={onReconnect}>Reconnect Now</a>] •
          [<a href="#" onClick={toggleShow}>hide</a>]
        </div>
      </Show>
    </div>
  }</Show>

export Countdown = (props) ->
  computeRemaining = ->
    Math.round (props.time - new Date().getTime()) / 1000
  [remaining, setRemaining] = createSignal computeRemaining()
  interval = setInterval (-> setRemaining computeRemaining), 1000
  onCleanup -> clearInterval interval
  <>{remaining()} seconds</>
