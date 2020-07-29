@Files = new FileCollection
  resumable: true
  resumableIndexName: 'files'
  http: [
    method: 'get'
    path: '/id/:_id'
    lookup: (params, query) ->
      _id: params._id
  ]
