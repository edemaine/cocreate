## Expire old 

import {fade} from '../lib/remotes.coffee'

expireFrequency = 5 * 60 * 1000  # 5 minutes

Meteor.setInterval ->
  Remotes.remove
    updated: $lt: new Date (new Date) - fade * 1000
, expireFrequency
