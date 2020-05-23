export create = (tag, attrs, events, children) ->
  elt = document.createElement tag
  attr elt, attrs if attrs?
  listen elt, events if events?
  elt.appendChild child for child in children if children?
  elt

export attr = (elt, attrs) ->
  for key, value of attrs when value?
    if typeof value == 'object'
      attr elt[key], value
    else
      elt[key] = value

export listen = (elt, events) ->
  for key, value of events when value?
    elt.addEventListener key, value
