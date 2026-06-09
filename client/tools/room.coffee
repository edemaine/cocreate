import {createEffect, createMemo, createResource, createSignal, Show} from 'solid-js'
import Modal from 'solid-bootstrap/esm/Modal'
import {useLocation} from 'solid-app-router'

import {defineTool} from './defineTool'
import {currentRoom} from '../AppState'
import {CloseIcon} from '../lib/icons'

[show, setShow] = createSignal false

defineTool
  name: 'linkRoom'
  category: 'room'
  icon: 'clipboard-link'
  help: 'Share a link to this room/board: show the URL, copy it to the clipboard, and show a QR code.'
  active: -> show()
  click: ->
    setShow not show()
  portal: ->
    location = useLocation()
    here = createMemo -> Meteor.absoluteUrl location.pathname +
      (if location.hash then '#' else '') + location.hash
    ## Clone link: visiting it gives each person their own separate copy
    cloneHere = createMemo -> Meteor.absoluteUrl "clone/#{currentRoom().id}"
    copyCloneLink = ->
      try
        navigator.clipboard.writeText cloneHere()
    ## Save URL to clipboard when shown
    createEffect ->
      return unless show()
      try
        navigator.clipboard.writeText here()
    ## Generate QR code
    [QRCode] = createResource show, -> (await import('qrcode-svg')).default
    qr = createMemo ->
      return unless show() and QRCode()
      new (QRCode())
        content: here()
        ecl: 'M'
        join: true
        container: 'svg-viewbox'
      .svg()
    onClose = -> setShow false

    <Modal show={show()} class="info" onHide={onClose}>
      <Modal.Header>
        <CloseIcon onClick={onClose}/>
        <Modal.Title>Link To This Cocreate Room/Board:</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <p class="center linkToRoom">
          <a href={here()}>{here()}</a>
        </p>
        <p>If possible, this URL has already been <b>copied to your clipboard</b>, so you can paste it into a chat or email to send it to people.</p>
        <p>On some browsers, you can <b>right click</b> on the URL to send it to other devices, or <b>long tap</b> to share it.</p>
        <Show when={qr()} fallback={<i>Generating QR code&hellip;</i>}>
          <p>To send the board to your mobile device (phone or tablet), scan this <b>QR code</b>:</p>
          <div class="qrCode" innerHTML={qr()}/>
        </Show>
        <hr/>
        <p class="center linkToRoom">
          <a href={cloneHere()}>{cloneHere()}</a>
        </p>
        <p>Send this <b>clone link</b> instead to give each person their own
        separate editable <b>copy</b> of this board (all pages and drawings
        included). The original board stays unchanged &mdash; handy for handing
        out a problem for students to work on and export individually.
        <button type="button" class="btn btn-secondary" onClick={copyCloneLink}>Copy clone link</button></p>
      </Modal.Body>
    </Modal>

defineTool
  name: 'newRoom'
  category: 'room'
  icon: 'door-plus-circle'
  help: 'Create a new room/board (with new URL) in a new browser tab/window'
  click: ->
    window.open '/'

defineTool
  name: 'dupRoom'
  category: 'room'
  icon: 'clone'
  help: 'Duplicate this entire board (all pages and drawings) to a new room/board, and open the copy in a new browser tab/window'
  click: ->
    Meteor.call 'roomDup', currentRoom().id, (error, roomId) ->
      if error?
        return console.error "Failed to duplicate room on server: #{error}"
      window.open "/r/#{roomId}"
