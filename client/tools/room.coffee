import {createMemo, createResource, Show} from 'solid-js'
import Modal from 'solid-bootstrap/esm/Modal'
import {createTracker} from 'solid-meteor-data'
import {useLocation} from 'solid-app-router'
import {ReactiveVar} from 'meteor/reactive-var'

import {defineTool} from './defineTool'
import {CloseIcon} from '../lib/icons'

showing = new ReactiveVar false

defineTool
  name: 'linkRoom'
  category: 'room'
  icon: 'clipboard-link'
  help: 'Share a link to this room/board: show the URL, copy it to the clipboard, and show a QR code.'
  active: -> showing.get()
  click: ->
    showing.set not showing.get()
  portal: ->
    show = createTracker -> showing.get()
    location = useLocation()
    here = createMemo -> Meteor.absoluteUrl location.pathname + location.hash
    [qr] = createResource (-> [show(), here()]), ([showVal, hereVal]) ->
      return unless showVal
      try
        navigator.clipboard.writeText hereVal
      QRCode = await import('qrcode-svg')
      new QRCode.default
        content: hereVal
        ecl: 'M'
        join: true
        container: 'svg-viewbox'
      .svg()
    onClose = -> showing.set false

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
        <Show when={not qr.loading} fallback={<i>Generating QR code&hellip;</i>}>
          <p>To send the board to your mobile device (phone or tablet), scan this <b>QR code</b>:</p>
          <div class="qrCode" innerHTML={qr()}/>
        </Show>
      </Modal.Body>
    </Modal>

defineTool
  name: 'newRoom'
  category: 'room'
  icon: 'door-plus-circle'
  help: 'Create a new room/board (with new URL) in a new browser tab/window'
  click: ->
    window.open '/'
