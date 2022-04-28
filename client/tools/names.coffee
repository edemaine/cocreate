import {For, createEffect, createSignal, createRoot} from 'solid-js'
import {createFind, createTracker} from 'solid-meteor-data'
import Overlay from 'solid-bootstrap/esm/Overlay'
import Tooltip from 'solid-bootstrap/esm/Tooltip'

import {defineTool} from './defineTool'
import {currentBoard, currentRoom, currentPage, gotoPageId} from '../AppState'
import {Tool} from '../Tool'
import {closeTooltip} from '../SoloTooltip'
import {id as remoteId} from '../lib/remotes'

[show, setShow] = createSignal false

defineTool
  name: 'names'
  category: 'names'
  icon: 'users'
  active: -> show()
  help: 'Show all users, and select user to jump to their cursor'
  hotkey: '@'
  click: -> setShow not show()

export Names = ->
  createEffect -> closeTooltip() if show()
  toolRef = null
  <>
    <Tool ref={toolRef} tool="names" placement="bottom"/>
    <Overlay target={-> toolRef} show={show()} placement="bottom-start"
     containerPadding="0">
      <Tooltip class="menu">
        <NameList/>
      </Tooltip>
    </Overlay>
  </>

export NameList = ->
  pages = createTracker -> currentRoom()?.data()?.pages
  remotes = createFind ->
    Remotes.find
      room: currentRoom().id
      _id: $ne: remoteId
    ,
      sort: name: 1

  <For each={remotes()} fallback={<div class="none">No other users.</div>}>{(remote) ->
    #return if remote._id == remoteId
    page = -> (1 + pages().indexOf remote.page) or '?'
    onClick = ->
      setShow false
      setView = ->
        return unless remote.cursor?
        currentBoard().translateToCenterOn remote.cursor.x, remote.cursor.y
      if currentPage().id == remote.page
        setView()
      else if 0 <= pages().indexOf remote.page
        gotoPageId remote.page
        ## Wait to arrive on page, then adjust view
        createRoot (dispose) ->
          createEffect ->
            if currentPage()?.id == remote.page
              setView()
              dispose()
    <div class="item" onClick={onClick}>
      {remote.name} [p{page()}]
    </div>
  }</For>
