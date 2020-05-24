###
The `icons` content below is edited SVG from Font Awesome Free which is
licensed under CC BY 4.0.  See https://fontawesome.com/ and
https://creativecommons.org/licenses/by/4.0/, respectively.
###

icons =
  'arrows-alt':
    '<path d="M352.201 425.775l-79.196 79.196c-9.373 9.373-24.568 9.373-33.941 0l-79.196-79.196c-15.119-15.119-4.411-40.971 16.971-40.97h51.162L228 284H127.196v51.162c0 21.382-25.851 32.09-40.971 16.971L7.029 272.937c-9.373-9.373-9.373-24.569 0-33.941L86.225 159.8c15.119-15.119 40.971-4.411 40.971 16.971V228H228V127.196h-51.23c-21.382 0-32.09-25.851-16.971-40.971l79.196-79.196c9.373-9.373 24.568-9.373 33.941 0l79.196 79.196c15.119 15.119 4.411 40.971-16.971 40.971h-51.162V228h100.804v-51.162c0-21.382 25.851-32.09 40.97-16.971l79.196 79.196c9.373 9.373 9.373 24.569 0 33.941L425.773 352.2c-15.119 15.119-40.971 4.411-40.97-16.971V284H284v100.804h51.23c21.382 0 32.09 25.851 16.971 40.971z"/>'
  eraser:
    '<path d="M497.941 273.941c18.745-18.745 18.745-49.137 0-67.882l-160-160c-18.745-18.745-49.136-18.746-67.883 0l-256 256c-18.745 18.745-18.745 49.137 0 67.882l96 96A48.004 48.004 0 0 0 144 480h356c6.627 0 12-5.373 12-12v-40c0-6.627-5.373-12-12-12H355.883l142.058-142.059zm-302.627-62.627l137.373 137.373L265.373 416H150.628l-80-80 124.686-124.686z"/>'
  'pencil-alt-solid':
    '<path d="M497.9 142.1l-46.1 46.1c-4.7 4.7-12.3 4.7-17 0l-111-111c-4.7-4.7-4.7-12.3 0-17l46.1-46.1c18.7-18.7 49.1-18.7 67.9 0l60.1 60.1c18.8 18.7 18.8 49.1 0 67.9zM284.2 99.8L21.6 362.4.4 483.9c-2.9 16.4 11.4 30.6 27.8 27.8l121.5-21.3 262.6-262.6c4.7-4.7 4.7-12.3 0-17l-111-111c-4.8-4.7-12.4-4.7-17.1 0zM124.1 339.9c-5.5-5.5-5.5-14.3 0-19.8l154-154c5.5-5.5 14.3-5.5 19.8 0s5.5 14.3 0 19.8l-154 154c-5.5 5.5-14.3 5.5-19.8 0zM88 424h48v36.3l-64.5 11.3-31.1-31.1L51.7 376H88v48z"/>'

viewBox = ' viewBox="0 0 512 512"'

formatAttrs = (attrs) ->
  parts = []
  for key, value of attrs
    parts.push "#{key}=\"#{value}\""
  if parts.length
    ' ' + parts.join ' '
  else
    ''

## Add fill/stroke/etc. attributes to all <path> elements in icon
export modIcon = (icon, attrs) ->
  icon = icons[icon] if icon of icons
  icon.replace /<path\b/g, "$&#{formatAttrs attrs}"

## Wrap icon in <svg>...</svg> tag
export svgIcon = (icon, attrs) ->
  icon = icons[icon] if icon of icons
  """<svg xmlns="http://www.w3.org/2000/svg"#{viewBox}#{formatAttrs attrs}>#{icon}</svg>"""

## Icons as mouse cursors

cursorSize = 32

round = (frac) ->
  Math.round frac * (cursorSize-1)

export iconCursor = (dom, icon, xFrac, yFrac) ->
  svg = svgIcon icon,
    width: cursorSize
    height: cursorSize
  dom.style.cursor = "url(\"data:image/svg+xml,#{encodeURIComponent svg}\")
    #{round xFrac} #{round yFrac}, crosshair"
