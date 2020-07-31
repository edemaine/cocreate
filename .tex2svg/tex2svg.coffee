## Based roughly on direct/tex2svg from
## https://github.com/mathjax/MathJax-demos-node

global.MathJax =
  tex: packages: 'base, autoload, require, ams, newcommand'
  svg: fontCache: 'none'
  startup: typeset: false

require 'mathjax-full/components/src/startup/lib/startup.js'
require 'mathjax-full/components/src/core/core.js'
require 'mathjax-full/components/src/adaptors/liteDOM/liteDOM.js'
require 'mathjax-full/components/src/input/tex-base/tex-base.js'
require 'mathjax-full/components/src/input/tex/extensions/all-packages/all-packages.js'
require 'mathjax-full/components/src/output/svg/svg.js'
require 'mathjax-full/components/src/output/svg/fonts/tex/tex.js'
require 'mathjax-full/components/src/startup/startup.js'

global.MathJax.loader.preLoad 'core', 'adaptors/liteDOM', 'input/tex-base',
  '[tex]/all-packages', 'output/svg', 'output/svg/fonts/tex'
global.MathJax.config.startup.ready()

console.log 'hello'
node = global.MathJax.tex2svg '\\int_0^1 x^2 \, dx',
  display: true
  #em: argv.em,
  #ex: argv.ex,
  #containerWidth: argv.width
console.log global.MathJax.startup.adaptor.outerHTML node
