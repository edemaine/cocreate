url = require("url")

apiMethods =
  "/roomNew" : (query, req, res, next) ->
    try
      result = Meteor.call "roomNew",
        grid: true
      [200, {id: "#{result}"}]
    catch e
      [500, {"error": "Error creating new room: #{e}"}]


WebApp.connectHandlers.use "/api", (req, res, next) ->
  url = url.parse req.url, true
  if apiMethods.hasOwnProperty url.pathname
    [status, out] = apiMethods[url.pathname](url.query, req, res, next)
    res.writeHead status, {"Content-type": "application/json"}
    res.end JSON.stringify(out)
  else
    res.writeHead 404
    res.end "Unknown API endpoint: #{url.path}"
