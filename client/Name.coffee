import {createTracker} from 'solid-meteor-data'

import storage from './lib/storage'

export name = new storage.StringVariable 'name', ''

export Name = ->
  nameVal = createTracker -> name.get()

  onKeyDown = (e) ->
    e.stopPropagation() # avoid width setting hotkey
  onInput = (e) ->
    name.set e.currentTarget.value

  <input id="name" type='text' placeholder='Your Name' value={nameVal()}
   onKeyDown={onKeyDown} onInput={onInput}/>
