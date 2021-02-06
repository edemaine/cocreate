import React from 'react'
import {useTracker} from 'meteor/react-meteor-data'

import storage from './lib/storage'

export name = new storage.StringVariable 'name', ''

export Name = React.memo ->
  nameVal = useTracker ->
    name.get()
  , []

  onKeyDown = (e) ->
    e.stopPropagation() # avoid width setting hotkey
  onInput = (e) ->
    name.set e.target.value

  <input id="name" type='text' placeholder='Your Name' value={nameVal}
   onKeyDown={onKeyDown} onInput={onInput}/>

Name.displayName = 'Name'
