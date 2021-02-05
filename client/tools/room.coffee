import React, {useLayoutEffect, useState} from 'react'
import Modal from 'react-bootstrap/Modal'
import {useTracker} from 'meteor/react-meteor-data'
import {useLocation} from 'react-router-dom'
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
  dom: -> # eslint-disable-line react/display-name
    show = useTracker ->
      showing.get()
    , []
    location = useLocation()
    here = Meteor.absoluteUrl location.pathname + location.hash
    [qr, setQr] = useState()
    useLayoutEffect ->
      if show
        try
          navigator.clipboard.writeText here
        import('qrcode-svg').then (QRCode) ->
          setQr (new QRCode.default
            content: here
            ecl: 'M'
            join: true
            container: 'svg-viewbox'
          ).svg()
      undefined
    , [show, here]
    onClose = -> showing.set false

    <Modal show={show} className="info" onHide={onClose}>
      <Modal.Header>
        <CloseIcon onClick={onClose}/>
        <Modal.Title>Link To This Cocreate Room/Board:</Modal.Title>
      </Modal.Header>
      <Modal.Body>
        <p className="center linkToRoom">
          <a href={here}>{here}</a>
        </p>
        <p>If possible, this URL has already been <b>copied to your clipboard</b>, so you can paste it into a chat or email to send it to people.</p>
        <p>On some browsers, you can <b>right click</b> on the URL to send it to other devices, or <b>long tap</b> to share it.</p>
        <p>To send the board to your mobile device (phone or tablet), scan this <b>QR code</b>:</p>
        <div className="qrCode" dangerouslySetInnerHTML={__html: qr}/>
      </Modal.Body>
    </Modal>

defineTool
  name: 'newRoom'
  category: 'room'
  icon: 'door-plus-circle'
  help: 'Create a new room/board (with new URL) in a new browser tab/window'
  click: ->
    window.open '/'
