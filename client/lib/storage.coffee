import {ReactiveVar} from 'meteor/reactive-var'

###
Variable storing JSONifiable data, remembered by localStorage.
Use `get()`/`set(val)` to access variable.
###
export class Variable extends ReactiveVar
  @parse: JSON.parse
  @stringify: JSON.stringify
  constructor: (@key, initial, @sync = true) ->
    super initial
    ## `initial` is default when nothing/invalid stored in localStorage.
    ## If `sync` is set, synchronize value with other browser tabs.
    try
      json = window?.localStorage?.getItem? @key
    catch e
      console.warn e
    if json
      try
        initial = @constructor.parse json
      @set initial
    if @sync
      window.addEventListener 'storage', @listener = (e) =>
        if e.key == @key
          try
            val = @constructor.parse e.newValue
          catch
            return
          ## Like @set val, but don't try to set localStorage again
          super.set val

  set: (val) ->
    super.set val
    try
      window?.localStorage?.setItem? @key, @constructor.stringify val
    catch e
      console.warn e
  setTemp: (val) -> # doesn't save to local storage, for coop protocol
    super.set val
  stop: ->
    window.removeEventListener 'storage', @listener if @listener?

export class StringVariable extends Variable
  @parse: (x) -> x
  @stringify: (x) -> x
