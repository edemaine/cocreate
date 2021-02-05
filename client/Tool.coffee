import React, {useEffect} from 'react'
import OverlayTrigger from 'react-bootstrap/OverlayTrigger'
import Tooltip from 'react-bootstrap/Tooltip'
import {useTracker} from 'meteor/react-meteor-data'

import {currentTool, tools, toolsByCategory, selectTool} from './tools/tools'
import icons from './lib/icons'

export ToolCategory = React.memo ({category, ...rest}) ->
  for tool of toolsByCategory[category]
    <Tool key={tool} tool={tool} {...rest}/>

export Tool = React.memo ({tool, placement}) ->
  toolSpec = tools[tool]
  selected = useTracker ->
    currentTool.get() == tool
  , [tool]
  if toolSpec.active
    active = useTracker toolSpec.active, []
  useEffect ->
    #toolSpec.init?()
  , []

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
    if toolSpec.click?
      toolSpec.click e
    else
      selectTool tool

  div =
    <div className={className} data-tool={tool} onClick={onClick}>
      {icon}
    </div>
  return div unless toolSpec.help?
  <OverlayTrigger placement={placement} overlay={(props) ->
    <Tooltip {...props}>
      {toolSpec.help}
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
  </OverlayTrigger>
