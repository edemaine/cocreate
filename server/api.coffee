url = require("url")

apiMethods =
  "/roomNew" : () ->
    try
      result = Meteor.call "roomNew",
        grid: true
      [200, {id: "#{result}"}]
    catch e
      [500, {"error": "Error creating new room: #{e}"}]


WebApp.connectHandlers.use "/api", (req, res, next) ->
  url = url.parse req.url, true
  if apiMethods.hasOwnProperty url.pathname
    result = apiMethods[url.pathname](url.query, req, res, next)
    if result != null
      res.writeHead result[0], {"Content-type": "application/json"}
      res.end JSON.stringify(result[1])
  else
    res.writeHead 404
    res.end "Unknown API endpoint: #{url.path}"
