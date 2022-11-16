import {defineTool} from './defineTool'
import {selectDrawingTool} from './tools'
import {currentBoard, currentDash, setCurrentDash} from '../AppState'

export dashes = [
  dash: null
  help: 'solid'
,
  dash: '0 2'
  help: 'dotted'
,
  dash: '2'
  help: 'dashed'
,
  dash: '0 2 2 2'
  help: 'dot-dashed'
]
setCurrentDash null

export scaleDash = (dash, width) ->
  return dash unless dash
  number = /[\d.]+/g
  (
    while (match = number.exec dash)?
      width * parseFloat match[0]
  ).join ' '

dashSize = 22

for {dash, help} in dashes
  do (dash, help) ->
    defineTool
      name: "dash:#{help}"
      category: 'dash'
      class: 'dash attrib'
      help: "Set line style to #{help}"
      active: -> currentDash() == dash
      click: ->
        setCurrentDash dash
        if (selection = currentBoard().selection)?.nonempty()
          selection.edit 'dash', currentDash()
        else
          selectDrawingTool()
      icon: ->
        <svg viewBox="0 #{-dashSize/2} #{dashSize} #{dashSize}"
         width={dashSize} height={dashSize}>
          <line x1={2} x2={dashSize - if dash then 0 else 2}
           stroke-linecap="round" stroke-width={3}
           stroke-dasharray={scaleDash dash, 3}/>
        </svg>
