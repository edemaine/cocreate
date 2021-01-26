import bodyParser from 'body-parser';

apiMethods =
  '/roomNew': (options, req) ->
    try
      body = req.body
      body.grid = Boolean JSON.parse body.grid or Boolean JSON.parse options.get 'grid'
      body.bg = Boolean JSON.parse body.bg or Boolean JSON.parse options.get 'bg'
      ids = Meteor.call 'roomNew', body
      status: 200
      json:
        ok: true
        id: ids.room
        url: Meteor.absoluteUrl "/r/#{ids.room}"
    catch e
      status: 500
      json:
        ok: false
        error: "Error creating new room: #{e}"

## Allow CORS for API calls
WebApp.rawConnectHandlers.use '/api', (req, res, next) ->
  res.setHeader 'Access-Control-Allow-Origin', '*'
  res.setHeader 'Access-Control-Allow-Methods', '*'
  res.setHeader 'Access-Control-Allow-Headers', '*'
  next()

WebApp.connectHandlers.use '/api', bodyParser.json({limit: '16mb'})

WebApp.connectHandlers.use '/api', (req, res, next) ->
  return unless req.method in ['GET', 'POST', 'OPTIONS']
  url = new URL req.url, Meteor.absoluteUrl()
  if apiMethods.hasOwnProperty url.pathname
    result = apiMethods[url.pathname] url.searchParams, req, res, next
  else
    result =
      status: 404
      json:
        ok: false
        error: "Unknown API endpoint: #{url.pathname}"
  unless res.headersSent
    res.writeHead result.status, 'Content-type': 'application/json'
  unless res.writeableEnded
    res.end JSON.stringify result.json
