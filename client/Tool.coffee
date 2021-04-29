import React from 'react'
import Tooltip from 'react-bootstrap/Tooltip'
import {useTracker} from 'meteor/react-meteor-data'

import {currentTool} from './AppState'
import {SoloTooltip, closeTooltip} from './SoloTooltip'
import {tools, toolsByCategory, clickTool} from './tools/tools'
import icons from './lib/icons'

export ToolCategory = React.memo ({category, ...rest}) ->
  for tool of toolsByCategory[category]
    <Tool key={tool} tool={tool} {...rest}/>
ToolCategory.displayName = 'ToolCategory'

export Tool = React.memo ({tool, placement}) ->
  toolSpec = tools[tool]
  selected = useTracker ->
    currentTool.get() == tool
  , [tool]
  if toolSpec.active
    active = useTracker toolSpec.active, []

  className = toolSpec.className ? 'tool'
  className += ' selected' if selected
  className += ' active' if active

  if typeof toolSpec.icon == 'function'
    icon = useTracker ->
      toolSpec.icon()
    , [toolSpec.icon]
  else
    icon = toolSpec.icon
  if typeof icon == 'string'
    if icon != icons.getIcon icon
      icon = icons.modIcon toolSpec.icon, fill: 'currentColor'
    icon = <span dangerouslySetInnerHTML={__html: icons.svgIcon icon}/>

  onClick = (e) ->
    closeTooltip()
    clickTool toolSpec, e

  div =
    <div className={className} data-tool={tool} onClick={onClick}>
      {icon}
      {toolSpec.portal?()}
    </div>
  return div unless toolSpec.help?
  <SoloTooltip id="tool:#{tool}" placement={placement} overlay={(props) ->
    <Tooltip {...props}>
      {if toolSpec.help instanceof Function
        toolSpec.help()
      else
        toolSpec.help
      }
      {if toolSpec.hotkey.length
        <>
          <span className="hotkeys">
            {for hotkey in toolSpec.hotkey
              <kbd key={hotkey} className="hotkey">{hotkey}</kbd>
            }
          </span>
          <div className="clear"/>
        </>
      }
    </Tooltip>
  }>
    {div}
  </SoloTooltip>

Tool.displayName = 'Tool'
