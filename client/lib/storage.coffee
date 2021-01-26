###
Variable storing JSONifiable data, remembered by localStorage.
Use `get()`/`set(val)` to access variable.
###
export class Variable
  @parse: JSON.parse
  @stringify: JSON.stringify
  constructor: (@key, initial, @sync) ->
    ## `initial` is default when nothing/invalid stored in localStorage.
    ## If `sync` is set, synchronize value with other browser tabs, and call
    ## `sync()` whenever the value changes in this way.
    @val = initial
    try
      json = window?.localStorage?.getItem? @key
    catch e
      console.warn e
    if json
      try
        @val = @constructor.parse json
      catch
    if @sync
      window.addEventListener 'storage', (e) =>
        if e.key == @key
          try
            @val = @constructor.parse e.newValue
          catch
          @sync()
  get: -> @val
  set: (val) ->
    @val = val
    try
      window?.localStorage?.setItem? @key, @constructor.stringify val
    catch e
      console.warn e
  setTemp: (val) -> # doesn't save to local storage, for coop protocol
    @val = val
  update: -> @sync()

export class StringVariable extends Variable
  @parse: (x) -> x
  @stringify: (x) -> x
