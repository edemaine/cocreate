# From Comingle

export meteorCallPromise = (...args) ->
  new Promise (resolve, reject) ->
    Meteor.call ...args, (error, response) ->
      if error?
        reject error
      else
        resolve response
