url = require('url')

apiMethods =
  "/roomNew" : (query, req, res, next) ->
    Meteor.call 'roomNew',
      grid: true,
      (error, room) ->
        if error?
          res.writeHead 500
          res.end "Failed to create new room: #{error}"
        else
          res.writeHead 200
          res.end "#{room}"


WebApp.connectHandlers.use '/api', (req, res, next) ->
  url = url.parse req.url, true
  if apiMethods.hasOwnProperty url.pathname
    apiMethods[url.pathname](url.query, req, res, next)
  else
    res.writeHead 404
    res.end "Unknown API endpoint: #{url.path}"
