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
  dev = Meteor.isDevelopment and
    new URL(Meteor.absoluteUrl()).hostname == 'localhost'
  if Meteor.settings.public['cors-anywhere'] ==
     'https://cors-anywhere.herokuapp.com/'
    if dev
      console.log "Using CORS Anywhere public test server, for development purposes only. Change settings.json to specify your CORS Anywhere server when deploying a public Cocreate server."
    else
      delete Meteor.settings.public['core-anywhere']
      console.log "Cannot use CORS Anywhere public test server in production; modify settings.json to specify your CORS Anywhere server."
  else if Meteor.settings.public['cors-anywhere'] ==
          'https://coproxy.csail.mit.edu:8080/'
    if dev
      console.log "Using Cocreate's CORS Anywhere server, for development purposes only. Change settings.json to specify your CORS Anywhere server when deploying a public Cocreate server."
    else if Meteor.absoluteUrl().hostname != 'cocreate.csail.mit.edu'
      delete Meteor.settings.public['core-anywhere']
      console.log "Cannot use Cocreate's CORS Anywhere server in production for any server other than the intended one; modify settings.json to specify your CORS Anywhere server."

export proxyUrl = (url) ->
  if proxy = Meteor.settings.public['cors-anywhere']
    "#{proxy}#{if proxy.endsWith '/' then '' else '/'}#{url}"
  else
    url
