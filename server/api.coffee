apiMethods =
  '/roomNew': (options) ->
    try
      id = Meteor.call 'roomNew',
        grid: Boolean JSON.parse options.get 'grid'
      status: 200
      json:
        ok: true
        id: id
        url: Meteor.absoluteUrl "/r/#{id}"
    catch e
      status: 500
      json:
        ok: false
        error: "Error creating new room: #{e}"

WebApp.connectHandlers.use '/api', (req, res, next) ->
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
