import {batch, createMemo, For, Show} from 'solid-js'
import {createStore, reconcile} from 'solid-js/store'
import Tooltip from 'solid-bootstrap/esm/Tooltip'
import {createTracker} from 'solid-meteor-data'

import {currentRoom, currentPage} from './AppState'
import {SoloTooltip} from './SoloTooltip'
import {Icon} from './lib/icons'
#import remotes from './lib/remotes'

export PageList = ->
  pages = createTracker -> currentRoom()?.data()?.pages

  ## Monitor state of remotes
  [remotesByPage, setRemotesByPage] = createStore {}
  createTracker ->
    return unless currentRoom()?
    Remotes.find
      room: currentRoom().id
    ,
      fields:
        page: true
        name: true
    .observe
      added: add = (remote) ->
        #return if remote._id == remotes.id  # ignore self
        batch ->
          setRemotesByPage remote.page, {}  # make empty object if not already
          setRemotesByPage remote.page, remote._id, reconcile remote
      removed: remove = (remote) ->
        #return if remote.id == remotes.id  # ignore self
        batch ->
          setRemotesByPage remote.page, remote._id, undefined
          setRemotesByPage remote.page, (pageRemotes) ->
            pageRemotes if Object.keys(pageRemotes).length
      changed: (remote, oldRemote) ->
        batch ->
          remove oldRemote
          add remote

  <Show when={pages()}>
    <div class="pageList">
      <For each={pages()}>{(pageId, index) ->
        active = -> (pageId == currentPage()?.id)
        pageRemotes = -> Object.keys remotesByPage[pageId] ? {}
        pageRemotesCount = createMemo -> pageRemotes().length
        <SoloTooltip id="page:#{pageId}" placement="bottom" overlay={
          <Tooltip>
            <div class="pageHeader">
              Page {index()+1} {if active() then '(this page)'}
            </div>
            {if pageRemotesCount()
              <>
                <hr/>
                <For each={pageRemotes()}>{(remoteId) ->
                  <span class="user">
                    <Icon class="icon" icon="user" fill="currentColor"/>
                    &nbsp;
                    <span>{remotesByPage[pageId][remoteId].name}</span>
                  </span>
                }</For>
              </>
            }
          </Tooltip>
        }>
          <a class="page #{if active() then 'active' else ''}"
          href="##{pageId}">
            {switch pageRemotesCount()
              when 0
                null
              when 1
                <Icon class="icon" icon="user" fill="currentColor"/>
              when 2
                <Icon class="icon" icon="user-friends" fill="currentColor"/>
              else
                <Icon class="icon" icon="users" fill="currentColor"/>
            }
            &nbsp;
            {index()+1}
          </a>
        </SoloTooltip>
      }</For>
    </div>
  </Show>
