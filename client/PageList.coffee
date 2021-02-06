import React, {useRef, useState} from 'react'
import {useTracker} from 'meteor/react-meteor-data'

import {currentRoom, currentPage} from './AppState'
import DrawApp from './DrawApp'
import {Icon} from './lib/icons'
import remotes from './lib/remotes'

export PageList = React.memo ->
  room = useTracker ->
    currentRoom.get()
  , []
  pages = useTracker ->
    room?.data()?.pages
  , [room]
  page = useTracker ->
    currentPage.get()
  , []

  ## Monitor state of remotes
  remotesByPage = useRef {}
  [counter, setCounter] = useState 0
  useTracker ->
    return unless room?
    increment = (c) -> if c >= Number.MAX_SAFE_INTEGER then 0 else c+1
    Remotes.find
      room: room.id
    ,
      fields:
        page: true
    .observe
      added: add = (remote) ->
        return if remote._id == remotes.id  # ignore self
        remotesByPage.current[remote.page] ?= {}
        remotesByPage.current[remote.page][remote._id] = remote
        setCounter increment
      removed: remove = (remote) ->
        return if remote.id == remotes.id  # ignore self
        delete remotesByPage.current[remote.page]?[remote._id]
        setCounter increment
      changed: (remote, oldRemote) ->
        remove oldRemote
        add remote
  , [room?.id]

  return null unless pages?
  <div className="pageList">
    {for pageId, index in pages
      active = (pageId == page?.id)
      pageRemotes = remotesByPage.current[pageId]
      pageRemotesCount =
        if pageRemotes?
          (key for key of pageRemotes).length
        else
          0
      do (pageId) ->
        <div key={pageId} className="page #{if active then 'active' else ''}"
         onClick={-> DrawApp.setPageId pageId}>
          {switch pageRemotesCount
            when 0
              null
            when 1
              <Icon className="icon" icon="user" fill="currentColor"/>
            when 2
              <Icon className="icon" icon="user-friends" fill="currentColor"/>
            else
              <Icon className="icon" icon="users" fill="currentColor"/>
          }
          {index+1}
        </div>
    }
  </div>