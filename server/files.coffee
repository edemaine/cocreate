Files.allow
  insert: (userId, file) ->
    file.metadata = {} unless file.metadata?
    check file.metadata, {}
    #file.metadata.uploader = userId
    true
  read: (userId, file) ->
    true
  ## Allow writing to any partial files (ID shouldn't be public until complete)
  remove: (userId, file) ->
    file.metadata._Resumable?
  write: (userId, file, fields) ->
    file.metadata._Resumable?
