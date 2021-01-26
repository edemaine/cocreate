import fs from 'fs'
import path from 'path'
import {icons} from '../../client/lib/icons'

## Icons in Cocreate render at size 24px plus 2px border
margin = Math.round (2/24) * 512
fill = '#ccc'

for name, svg of icons
  fs.writeFileSync path.join(__dirname, "#{name}.svg"), """
    <?xml version="1.0" encoding="utf-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="#{-margin} #{-margin} #{512+2*margin} #{512+2*margin}">
    <rect x="#{-margin}" y="#{-margin}" width="#{512+2*margin}" height="#{512+2*margin}" fill="#{fill}"/>
    #{svg}
    </svg>

  """
