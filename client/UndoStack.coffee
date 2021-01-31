## Undoable operations and undo/redo stacks

export class UndoStack
  constructor: ->
    @undoStack = []
    @redoStack = []
  push: (op) ->
    @redoStack = []
    @undoStack.push op
  pushAndDo: (op) ->
    @push op
    doOp op
  remove: (op) ->
    index = @undoStack.indexOf op
    @undoStack.splice index, 1 if index >= 0
  undo: ->
    ## Returns an array of object IDs to set the selection to,
    ## or `undefined` if undo failed (nothing to undo).
    return unless @undoStack.length
    op = @undoStack.pop()
    doOp op, true
    @redoStack.push op
    selectOp op, true
  redo: ->
    ## Returns an array of object IDs to set the selection to,
    ## or `undefined` if redo failed (nothing to redo).
    return unless @redoStack.length
    op = @redoStack.pop()
    doOp op, false
    @undoStack.push op
    selectOp op, false

## Perform an undoable operation, or the reverse of that operation,
## according to whether `reverse` is `false` or `true`.
doOp = (op, reverse = false) ->
  editArgs = (sub) ->
    Object.assign
      id: sub.id
    ,
      if reverse
        sub.before
      else
        sub.after
  switch op.type
    when 'multi'
      ops = op.ops
      ops = ops[..].reverse() if reverse
      if ops.every (sub) -> sub.type == 'edit'
        Meteor.call 'objectsEdit',
          for sub in ops
            editArgs sub
      else
        for sub in ops
          doOp sub, reverse
    when 'new', 'del'
      if (op.type == 'new') == reverse
        Meteor.call 'objectDel', op.obj._id
      else
        #obj = {}
        #for key, value of op.obj
        #  obj[key] = value unless key of skipKeys
        #op.obj._id = Meteor.apply 'objectNew', [obj], returnStubValue: true
        id = Meteor.apply 'objectNew', [op.obj], returnStubValue: true
        op.obj._id ?= id  # for pushAndDo to support later undo
        id
    when 'edit'
      Meteor.call 'objectEdit', editArgs op
    else
      console.error "Unknown op type #{op.type} for undo/redo"

## Returns the array of object IDs to set the selection to, as "acted upon" by
## the given undoable operation or the reverse of that operation.
selectOp = (op, reverse = false) ->
  recurse = (sub) ->
    if sub.selection? and reverse
      sub.selection
    else
      switch sub.type
        when 'new', 'del'
          if (sub.type == 'new') == reverse  # delete
            []
          else  # insert
            [sub.obj._id]
        when 'edit'
          [sub.id]
        when 'multi'
          [].concat ...(recurse part for part in sub.ops)
        else
          []
  recurse op
