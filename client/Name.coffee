import {createTracker} from 'solid-meteor-data'
import Tooltip from 'solid-bootstrap/esm/Tooltip'

import {SoloTooltip} from './SoloTooltip'
import storage from './lib/storage'

export name = new storage.StringVariable 'name', ''

export Name = ->
  nameVal = createTracker -> name.get()

  onKeyDown = (e) ->
    e.stopPropagation() # avoid width setting hotkey
  onInput = (e) ->
    name.set e.currentTarget.value

  <SoloTooltip id="name:input" placement="bottom" overlay={
    <Tooltip>
      Type your name (shown to other users next to your cursor)
    </Tooltip>
  }>
    <input id="name" type='text' placeholder='Your Name' value={nameVal()}
     onKeyDown={onKeyDown} onInput={onInput}/>
  </SoloTooltip>
