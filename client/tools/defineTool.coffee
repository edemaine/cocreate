## To avoid import cycles, this file should not import anything.

export tools = {}
export toolsByCategory = {}
export toolsByHotkey = {}

export defineTool = (toolSpec) ->
  tools[toolSpec.name] = toolSpec
  if toolSpec.category?
    category = toolsByCategory[toolSpec.category] ?= {}
    category[toolSpec.name] = toolSpec
  toolSpec.hotkey ?= []
  toolSpec.hotkey = [toolSpec.hotkey] unless Array.isArray toolSpec.hotkey
  for hotkey in toolSpec.hotkey
    hotkey = hotkey.replace /\s/g, ''
    toolsByHotkey[hotkey] = toolSpec
