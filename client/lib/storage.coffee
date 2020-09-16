###
Variable storing JSONifiable data, remembered by localStorage.
Use `get()`/`set(val)` to access variable.
###
export class Variable
  @storage: window?.localStorage
  constructor: (@key, initial, sync) ->
    ## `initial` is default when nothing/invalid stored in localStorage
    ## If `sync` is set, synchronize value with other browser tabs, and call
    ## `sync()` whenever the value changes in this way.
    json = @constructor.storage?.getItem? @key
    @val = initial
    if json
      try
        @val = JSON.parse json
      catch
    if sync
      window.addEventListener 'storage', (e) =>
        if e.key == @key
          try
            @val = JSON.parse e.newValue
          catch
          sync()
  get: -> @val
  set: (val) ->
    @val = val
    @constructor.storage?.setItem? @key, JSON.stringify val
