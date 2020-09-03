## For 'room' subscription
Pages.rawCollection().createIndex
  room: 1

## For 'room' subscription
Remotes.rawCollection().createIndex
  room: 1

## For 'room' subscription
Objects.rawCollection().createIndex
  room: 1

## For 'history' method
ObjectsDiff.rawCollection().createIndex
  room: 1
  page: 1
