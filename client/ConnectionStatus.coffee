import {createEffect, createResource, createSignal, onCleanup, Show} from 'solid-js'
import {createFindOne} from 'solid-meteor-data'
import {useLocation} from 'solid-app-router'
import {Reload} from 'meteor/reload'

[migrate, setMigrate] = createSignal false
readyToMigrate = false

## Based on Coauthor's client/lib/migrate.coffee
## See https://github.com/meteor/meteor/blob/master/packages/reload/reload.js
Reload._onMigrate 'cocreate', (retry) ->
  setMigrate -> retry
  ## Return format: [ready, optionalState]
  [readyToMigrate]

onMigrate = (e) ->
  e.preventDefault()
  readyToMigrate = true
  migrate()()

export ConnectionStatus = ->
  [show, setShow] = createSignal true
  [, status] = createFindOne -> Meteor.status()

  ## Ignore initial connecting status
  [initialized, setInitialized] = createSignal false
  createEffect ->
    setInitialized true if status.status != 'connecting'
  disconnected = ->
    initialized() and not status.connected

  onReconnect = (e) ->
    e.preventDefault()
    Meteor.reconnect()
  toggleShow = (e) ->
    e.preventDefault()
    setShow not show()

  <Show when={migrate() or disconnected()}>{->
    setShow true
    <div classList={
      offline: true
      show: show()
    }>
      <Show when={show()} fallback={
        <>[<a href="#" onClick={toggleShow}>show</a>]</>
      }>
        <Show when={migrate()}>
          <MigrateMessage/>
        </Show>
        <Show when={disconnected()}>
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
        </Show>
        <div>
          <Show when={migrate()}>
            [<a href="#" onClick={onMigrate}>Migrate&nbsp;Now</a>]
            {' • '}
          </Show>
          <Show when={disconnected()}>
            [<a href="#" onClick={onReconnect}>Reconnect&nbsp;Now</a>]
            {' • '}
          </Show>
          [<a href="#" onClick={toggleShow}>hide</a>]
        </div>
      </Show>
    </div>
  }</Show>

export MigrateMessage = ->
  location = useLocation()
  here = -> Meteor.absoluteUrl location.pathname +
    (if location.hash then '#' else '') + location.hash
  [changelog] = createResource ->
    (await import('/package.json')).changelog

  <>
    <h1>Cocreate Updated</h1>
    <p>
      The server wants to migrate to a new version of Cocreate; see <a href={changelog()} target="_blank">the changelog</a> for what's new.  You can click “<a href="#" onClick={onMigrate}>Migrate Now</a>” or reload to upgrade.  If you've been drawing recently, you should first check that your latest changes are <a href={here()} target="_blank">visible in another browser tab</a>; if anything is missing, copy and paste from here to the new tab. Then close or migrate/reload this tab.
    </p>
  </>

export Countdown = (props) ->
  computeRemaining = ->
    Math.round (props.time - new Date().getTime()) / 1000
  [remaining, setRemaining] = createSignal computeRemaining()
  interval = setInterval (-> setRemaining computeRemaining), 1000
  onCleanup -> clearInterval interval
  <>{remaining()} seconds</>
