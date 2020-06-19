url = require 'url'

apiMethods =
  '/roomNew': (options) ->
    try
      result = Meteor.call 'roomNew',
        grid: new Boolean options.grid
      status: 200
      json:
        ok: true
        id: result
        url: Meteor.absoluteUrl "/r/#{id}"
    catch e
      status: 500
      json:
        ok: false
        error: "Error creating new room: #{e}"

WebApp.connectHandlers.use '/api', (req, res, next) ->
  query = url.parse req.url, true
  if apiMethods.hasOwnProperty query.pathname
    result = apiMethods[query.pathname] query.searchParams, req, res, next
    unless res.headersSent
      res.writeHead result.status, 'Content-type': 'application/json'
    unless res.writeableEnded
      res.end JSON.stringify result.json
  else
    res.writeHead 404
    res.end "Unknown API endpoint: #{query.path}"
