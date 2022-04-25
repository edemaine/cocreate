import {splitProps, Show} from 'solid-js'
import Tooltip from 'solid-bootstrap/esm/Tooltip'
import {createTracker} from 'solid-meteor-data'

import {currentTool} from './AppState'
import {SoloTooltip, closeTooltip} from './SoloTooltip'
import {tools, toolsByCategory, clickTool} from './tools/tools'
import icons from './lib/icons'

export ToolCategory = (props) ->
  [local, rest] = splitProps props, ['category']
  for tool of toolsByCategory[local.category]
    <Tool tool={tool} {...rest}/>

export Tool = (props) ->
  toolSpec = -> tools[props.tool]
  selected = -> currentTool() == props.tool
  active = createTracker -> toolSpec().active?()

  icon = createTracker ->
    icon = toolSpec().icon
    icon = icon() if typeof icon == 'function'
    if typeof icon == 'string'
      if icon != icons.getIcon icon
        icon = icons.modIcon toolSpec().icon, fill: 'currentColor'
      icon = <span innerHTML={icons.svgIcon icon}/>
    icon

  onClick = (e) ->
    closeTooltip()
    clickTool toolSpec(), e

  div =
    <div class={toolSpec().class ? 'tool'}
     classList={selected: selected(), active: active()}
     data-tool={props.tool} onClick={onClick}>
      {icon()}
      {toolSpec().portal?()}
    </div>
  <Show when={toolSpec().help?} fallback={div}>
    <SoloTooltip id="tool:#{props.tool}" placement={props.placement} overlay={
      <Tooltip>
        {toolSpec().help}
        {if toolSpec().hotkey.length
          <>
            <span class="hotkeys">
              {for hotkey in toolSpec().hotkey
                <kbd class="hotkey">{hotkey}</kbd>
              }
            </span>
            <div class="clear"/>
          </>
        }
      </Tooltip>
    }>
      {div}
    </SoloTooltip>
  </Show>
