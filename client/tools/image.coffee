## See modes.coffee for the image mode that uses this.

import {validUrl, proxyUrl} from '/lib/url'
import {currentRoom, currentPage} from '../DrawApp'
import {undoStack} from '../UndoStack'

export tryAddImage = (items, options) ->
  ## HTML <img> tag (as from dragging images) or <a href> tag
  ## (without nested <a> links, as from dragging links)
  ## are highest priority.
  for item in items when item.type == 'text/html'
    html = await new Promise (done) -> item.getAsString done
    match = ///^\s* <img\b [^<>]* \b src \s*=\s* ("[^"]*"|'[^']*')
                      [^<>]*> \s*$///i.exec(html) or
    ///^\s* <a\b [^<>]* \b href \s*=\s* ("[^"]*"|'[^']*')
              [^<>]*> ([^]*) </a> \s*$///i.exec(html)
    if match? and not (match[2] and ///</a>///i.test match[2])
      url = match[1][1...match[1].length-1]
      return image if image = await tryAddImageUrl url, options
  ## Next check for plain text that consists solely of a URL
  for item in items when item.type == 'text/plain'
    text = await new Promise (done) -> item.getAsString done
    text = text.trim()
    return image if image = await tryAddImageUrl text, options
  false

## Asynchronously try to verify URL points to an image, and if so,
## add it to the current room and page and return the new object ID.
## `options` should not be provided; instead, it will be modified
## automatically to find a workable method.
export tryAddImageUrl = (url, options = {}) ->
  return unless validUrl url
  fetchUrl =
    if options.proxy
      proxyUrl url
    else
      url
  fetchOptions =
    cache: 'reload' # don't use cache while testing whether need credentials
    mode: 'cors'
    credentials: if options.credentials then 'include' else 'same-origin'
  ## Test whether image will load successfully by manually running a CORS
  ## preflight test (OPTIONS); then load content-type via HEAD request.
  try
    for method in ['OPTIONS', 'HEAD']
      response = await fetch fetchUrl, Object.assign {method}, fetchOptions
  catch e
    if Meteor.settings.public['cors-anywhere'] and
        not options.proxy and not options.credentials
      console.log "URL #{fetchUrl} failed to load, likely blocked by CORS; trying again with proxy"
      return tryAddImageUrl url, Object.assign options, proxy: true
    else
      console.log "URL #{fetchUrl} failed to load (#{e}) :-("
      return
  ## Status: Unauthorized or Forbidden -> try again with credentials
  ## (e.g. for Coauthor images)
  if response.status in [401, 403] and
     not options.credentials and not options.proxy
    console.log "URL #{fetchUrl} returned status #{response.status} from server; trying again with credentials"
    return tryAddImageUrl url, Object.assign options, credentials: true
  unless response.status in [200, 204]
    console.log "URL #{fetchUrl} returned status #{response.status} from server :-("
    return
  contentType = response.headers.get 'content-type'
  unless /^image\//.test contentType
    console.log "URL #{fetchUrl} has content-type #{contentType} which is not a supported image type"
    return
  obj =
    room: currentRoom.get().id
    page: currentPage.get().id
    type: 'image'
    url: url
    credentials: Boolean options.credentials
    proxy: Boolean options.proxy
  for key in ['pts', 'tx', 'ty']
    if key of options
      obj[key] = options[key]
  unless options.objOnly
    undoStack.pushAndDo
      type: 'new'
      obj: obj
  obj
