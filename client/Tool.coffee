import React, {useEffect, useRef} from 'react'
import Overlay from 'react-bootstrap/Overlay'
import Tooltip from 'react-bootstrap/Tooltip'
import {useTracker} from 'meteor/react-meteor-data'

import {currentTool} from './AppState'
import {tools, toolsByCategory, clickTool} from './tools/tools'
import dom from './lib/dom'
import icons from './lib/icons'

export ToolCategory = React.memo ({category, ...rest}) ->
  for tool of toolsByCategory[category]
    <Tool key={tool} tool={tool} {...rest}/>
ToolCategory.displayName = 'ToolCategory'

showTooltip = new ReactiveVar

export Tool = React.memo ({tool, placement}) ->
  toolSpec = tools[tool]
  selected = useTracker ->
    currentTool.get() == tool
  , [tool]
  if toolSpec.active
    active = useTracker toolSpec.active, []

  ## Tooltip triggers
  divRef = useRef()
  show = useTracker ->
    showTooltip.get() == tool
  , []
  useEffect ->
    dom.listen divRef.current,
      pointerenter: -> showTooltip.set tool
      pointerleave: -> showTooltip.set null

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
    clickTool toolSpec, e
    showTooltip.set null

  div =
    <div className={className} data-tool={tool} onClick={onClick} ref={divRef}>
      {icon}
      {toolSpec.portal?()}
    </div>
  return div unless toolSpec.help?
  <>
    {div}
    <Overlay target={divRef.current} placement={placement} show={show}>
      {(props) ->
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
      }
    </Overlay>
  </>

Tool.displayName = 'Tool'
