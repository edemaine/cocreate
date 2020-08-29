import fs from 'fs'
import path from 'path'
import {icons} from '../../client/lib/icons'

for name, svg of icons
  fs.writeFileSync path.join(__dirname, "#{name}.svg"), """
    <?xml version="1.0" encoding="utf-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
    #{svg}
    </svg>

  """
