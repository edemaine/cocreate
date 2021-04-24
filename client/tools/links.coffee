import {defineTool} from './defineTool'

defineTool
  name: 'github'
  category: 'link'
  icon: 'github'
  help: 'Go to Github repository: documentation, source code, bug reports, and feature requests'
  click: ->
    import('/package.json').then (json) ->
      window.open json.homepage, '_blank', 'noopener'

defineTool
  name: 'help'
  category: 'link'
  icon: 'question-circle'
  help: 'Open the Cocreate User Guide for online help'
  click: ->
    import('/package.json').then (json) ->
      window.open json.documentation, '_blank', 'noopener'
