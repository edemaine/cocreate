import React from 'react'
import {useTracker} from 'meteor/react-meteor-data'

import {currentRoom} from './AppState'

export RoomName = React.memo ->
  room = useTracker ->
    currentRoom.get()
  , []
  nameVal = useTracker ->
    room?.data()?.name || ''
  , [room]

  onKeyDown = (e) ->
    e.stopPropagation() # avoid width setting hotkey
  onInput = (e) ->
    return unless room?
    Meteor.call 'roomSetName', room.id, e.target.value

  <input id="name" type='text' placeholder='Room Name' value={nameVal}
   onKeyDown={onKeyDown} onInput={onInput}/>

RoomName.displayName = 'RoomName'
