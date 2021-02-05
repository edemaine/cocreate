import {defineTool} from './defineTool'

defineTool
  name: 'linkRoom'
  category: 'room'
  icon: 'clipboard-link'
  help: 'Share a link to this room/board: show the URL, copy it to the clipboard, and show a QR code.'
  click: toggleLinkRoom = ->
    dom.classToggle document.getElementById('qrCode'), 'show'
    dom.classToggle document.querySelector('.tool[data-tool="linkRoom"]'),
      'active'
    if document.getElementById('qrCode').classList.contains 'show'
      try
        navigator.clipboard.writeText document.URL
      close = document.querySelector '#qrCode .close'
      close.innerHTML = icons.svgIcon \
        icons.modIcon 'times-circle', fill: 'currentColor'
      close.removeEventListener 'click', toggleLinkRoom
      close.addEventListener 'click', toggleLinkRoom
      document.getElementById('qrCodeSvg').innerHTML = ''
      updateRoomLink = ->
        document.getElementById('linkToRoom').href = document.URL
        document.getElementById('linkToRoom').innerText = document.URL
        import('qrcode-svg').then (QRCode) ->
          document.getElementById('qrCodeSvg').innerHTML =
            new QRCode.default
              content: document.URL
              ecl: 'M'
              join: true
              container: 'svg-viewbox'
            .svg()
      updateRoomLink()
    else
      updateRoomLink = null

defineTool
  name: 'newRoom'
  category: 'room'
  icon: 'door-plus-circle'
  help: 'Create a new room/board (with new URL) in a new browser tab/window'
  click: ->
    window.open '/'
