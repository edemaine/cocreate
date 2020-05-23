cursorSize = 32
iconPath = (icon) -> "/fa/#{icon}.svg"

round = (frac) ->
  Math.round frac * (cursorSize-1)

@iconCursor = (dom, icons, xFrac, yFrac) ->
  icons = [icons] unless icons.length?
  svg = ["""<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="#{cursorSize}" height="#{cursorSize}">"""]
  for icon in icons
    data = await fetch iconPath icon.icon
    data = await data.text()
    data = data.replace /<svg.*?viewBox/, '<svg viewBox'
    svg.push data.replace /currentColor/g, icon.color
  svg.push """</svg>"""
  dom.style.cursor = "url(\"data:image/svg+xml,#{encodeURIComponent svg}\")
    #{round xFrac} #{round yFrac}, crosshair"
