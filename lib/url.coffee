## URL regular expression with scheme:// required, to avoid extraneous matching
## (from Coauthor)
urlRe = /^(\w+):\/\/[-\w~!$&'()*+,;=.:@%#?\/]+$/

myProtocol = null
Meteor.startup ->
  myProtocol = urlRe.exec(Meteor.absoluteUrl())[1]

export validUrl = (url) ->
  return false unless typeof url == 'string'
  match = urlRe.exec url
  return false unless match?
  protocol = match[1]
  protocol == myProtocol or
  myProtocol == 'http' and protocol == 'https'

Meteor.startup ->
  if Meteor.settings.public['cors-anywhere'] ==
     'https://cors-anywhere.herokuapp.com/'
    if Meteor.isDevelopment and
       new URL(Meteor.absoluteUrl()).hostname == 'localhost'
      console.log "Using CORS Anywhere public test server, for development purposes only. Change settings.json to specify your CORS Anywhere server when deploying a public Cocreate server."
    else
      delete Meteor.settings.public['core-anywhere']
      console.log "Cannot use CORS Anywhere public test server in production; modify settings.json to specify your CORS Anywhere server."

export proxyUrl = (url) ->
  if proxy = Meteor.settings.public['cors-anywhere']
    "#{proxy}#{if proxy.endsWith '/' then '' else '/'}#{url}"
  else
    url
