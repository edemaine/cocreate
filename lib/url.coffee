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

export proxyUrl = (url) ->
  if proxy = Meteor.settings.public['cors-anywhere']
    "#{proxy}#{if proxy.endsWith '/' then '' else '/'}#{url}"
  else
    url
