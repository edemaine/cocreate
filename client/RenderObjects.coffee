## RenderObjects class handles rendering and rerendering of objects on a board.
## (Arguably, it should be merged with Board.)

import {proxyUrl} from '../lib/url'
import dom from './lib/dom'
import icons from './lib/icons'
import {scaleDash} from './tools/dash'
import {pointers} from './tools/modes'
import {tools} from './tools/defineTool'
import {anchorObjectTypes, anchorsOf, anchorRadius, anchorStroke} from './Anchor'
import {BBox, minSvgSize} from './BBox'
import {penArrowAverage, averageDirection} from './Collision'
#import {DBVT} from './DBVT'

export class RenderObjects
  constructor: (@board) ->
    @root = @board.root
    @dom = {}
    @tex = {}
    @texQueue = []
    @texById = {}
    @bbox = {}
    @dashOffset = {}
    @arrows = new Set
    #@dbvt = new DBVT()
  stop: ->
    @stopped = true
    for arrowId from @arrows
      document.getElementById(arrowId)?.remove()
  id: (obj) ->
    ###
    `obj` can be an `ObjectDiff` object, in which case `id` is the object ID
    (and `_id` is the diff ID); or a regular `Object` object, in which case
    `_id` is the object ID.  Also allow raw ID string for `delete`.
    ###
    obj.id ? obj._id ? obj
  makeArrow: (color) ->
    ## Dreaming of `context-stroke` when one marker will suffice.
    ## [https://svgwg.org/svg2-draft/painting.html#TermContextElement]
    arrowId = "arrow-#{color}"
    unless @arrows.has arrowId
      arrow = document.getElementById 'arrow'
      coloredArrow = arrow.cloneNode true
      coloredArrow.id = arrowId
      coloredArrow.firstChild.setAttribute 'fill', color
      arrow.parentNode.insertBefore coloredArrow, arrow
      @arrows.add arrowId
    "url(##{arrowId})"
  renderPen: (obj, options) ->
    id = @id obj
    transparent = obj.opacity? and obj.opacity != 1
    ## Pen consists of a <g> containing <line>s and/or <polyline>s; see below.
    ## Redraw from scratch if no `start` specified,
    ## or if color/width/dash/arrow/opacity changed,
    ## or if object has any transparency.
    ## Redraw from scratch if no `start` specified, or if color/width/opacity
    ## changed, or object has any transparency.
    if options?.start? and not (options.color or options.width or options.dash or options.arrowStart or options.arrowEnd or options.opacity or transparent)
      start = options.start
      dashOffset = @dashOffset[id] ? 0
    else
      start = 0
      dashOffset = 0
    ## Choose between two rendering modes for this batch of points:
    ## * "Simple" mode: when all points have w == 1, use a single <polyline>
    ## * "Complex" mode: otherwise, use many <line>s
    ## We currently also use simple mode when the pen has transparency,
    ## to avoid overlap patterns between consecutive lines.
    simple = true
    unless transparent
      for i in [start...obj.pts.length]
        unless obj.pts[i].w == 1
          simple = false
          break
    ## In complex mode, create a document fragment for adding several
    ## <line> elements to the DOM tree at once, unless in dash mode
    ## where we need immediate computed lengths.
    if (exists = @dom[id])?
      ## Destroy existing drawing if starting over
      exists.innerHTML = '' if start == 0
      if simple or obj.dash
        frag = exists
      else
        frag = document.createDocumentFragment()
    else
      frag = dom.create 'g',
        class: 'pen'
      ,
        dataset: id: id
      ## In dash mode, we immediately add to the DOM tree for computed lengths.
      @root.appendChild @dom[id] = frag if obj.dash
    if simple
      frag.appendChild polyline = dom.create 'polyline',
        points: (
          for i in [start - (start > 0)...obj.pts.length]
            pt = obj.pts[i]
            "#{pt.x},#{pt.y}"
        ).join ' '
        stroke: obj.color
        'stroke-opacity': obj.opacity
        'stroke-width': obj.width
        'stroke-dasharray': scaleDash obj.dash, obj.width
        'stroke-dashoffset': if obj.dash then dashOffset
      dashOffset += polyline.getTotalLength() if obj.dash
    else
      ## Draw an `edge` between consecutive dots.
      ## (`dot` at each point replaced by stroke-linecap of `edge`.)
      if start == 0
        #frag.appendChild dot obj, obj.pts[0]
        start = 1
      for i in [start...obj.pts.length]
        prev = obj.pts[i-1]
        next = obj.pts[i]
        frag.appendChild line = dom.create 'line',
          x1: prev.x
          y1: prev.y
          x2: next.x
          y2: next.y
          stroke: obj.color
          'stroke-opacity': obj.opacity
          #'stroke-width': obj.width * (prev.w + next.w) / 2
          'stroke-width': obj.width * next.w
          ## Replace `dot` with round linecap, now set in CSS.
          #'stroke-linecap': 'round'
          'stroke-dasharray': scaleDash obj.dash, obj.width
          'stroke-dashoffset': if obj.dash then dashOffset
        dashOffset += line.getTotalLength() if obj.dash
        #frag.appendChild edge obj, prev, next
        #frag.appendChild dot obj, pt  # alternative to linecap: round
    @dashOffset[id] = dashOffset if obj.dash
    ## Arrowheads
    if (obj.arrowStart or obj.arrowEnd) and obj.pts.length > 1
      arrow = @makeArrow obj.color
      if obj.arrowStart
        if exists? and start > 1
          arrowStart = exists.querySelector '[marker-start]'
        else
          frag.insertBefore (arrowStart = dom.create 'line',
            stroke: obj.color
            'stroke-opacity': obj.opacity
            'stroke-width': obj.width
            'marker-start': arrow
            x1: obj.pts[0].x
            y1: obj.pts[0].y
          ), frag.firstChild
        {dx, dy} = averageDirection obj.pts[...penArrowAverage]
        dom.attr arrowStart,
          x2: obj.pts[0].x + dx
          y2: obj.pts[0].y + dy
      if obj.arrowEnd
        if exists? and start > 1
          arrowEnd = exists.querySelector '[marker-end]'
        else
          frag.insertBefore (arrowEnd = dom.create 'line',
            stroke: obj.color
            'stroke-opacity': obj.opacity
            'stroke-width': obj.width
            'marker-end': arrow
          ), frag.firstChild
        {dx, dy} = averageDirection obj.pts[-penArrowAverage..].reverse()
        {x, y} = obj.pts[obj.pts.length-1]
        dom.attr arrowEnd,
          x1: x + dx
          y1: y + dy
          x2: x
          y2: y
    ## Outside dash mode, we add to the DOM tree at the end for fewer renders.
    unless obj.dash
      if exists
        exists.appendChild frag unless simple
      else
        @root.appendChild @dom[id] = frag
    @dom[id]
  renderPoly: (obj) ->
    id = @id obj
    unless (poly = @dom[id])?
      @root.appendChild @dom[id] = poly =
        dom.create 'polyline', null, dataset: id: id
    arrow = @makeArrow obj.color if obj.arrowStart or obj.arrowEnd
    dom.attr poly,
      points: ("#{x},#{y}" for {x, y} in obj.pts).join ' '
      stroke: obj.color
      'stroke-opacity': obj.opacity
      'stroke-width': obj.width
      'stroke-dasharray': scaleDash obj.dash, obj.width
      'stroke-linecap': 'round'
      'stroke-linejoin': 'round'
      fill: obj.fill or 'none'
      'fill-opacity': obj.opacity
      'marker-start': if obj.arrowStart then arrow
      'marker-end': if obj.arrowEnd then arrow
    poly
  renderRect: (obj) ->
    id = @id obj
    unless (rect = @dom[id])?
      @root.appendChild @dom[id] = rect =
        dom.create 'rect', null, dataset: id: id
    dim = dom.pointsToRect obj.pts[0], obj.pts[1], minSvgSize
    dom.attr rect, Object.assign dim,
      stroke: obj.color
      'stroke-opacity': obj.opacity
      'stroke-width': obj.width
      'stroke-linecap': if obj.dash then 'round'
      'stroke-dasharray': scaleDash obj.dash, obj.width
      'stroke-linejoin': 'round'
      fill: obj.fill or 'none'
      'fill-opacity': obj.opacity
    rect
  renderEllipse: (obj) ->
    id = @id obj
    unless (ellipse = @dom[id])?
      @root.appendChild @dom[id] = ellipse =
        dom.create 'ellipse', null, dataset: id: id
    {x, y, width, height} = dom.pointsToRect obj.pts[0], obj.pts[1], minSvgSize
    rx = width / 2
    ry = height / 2
    dom.attr ellipse,
      cx: x + rx
      cy: y + ry
      rx: rx
      ry: ry
      stroke: obj.color
      'stroke-opacity': obj.opacity
      'stroke-width': obj.width
      'stroke-linecap': if obj.dash then 'round'
      'stroke-dasharray': scaleDash obj.dash, obj.width
      fill: obj.fill or 'none'
      'fill-opacity': obj.opacity
    ellipse
  renderText: (obj, options) ->
    id = @id obj
    unless (wrapper = @dom[id])?
      @root.appendChild @dom[id] = wrapper =
        dom.create 'g', null,
          dataset: id: id
      wrapper.appendChild g = dom.create 'g'
      g.appendChild rect = dom.create 'rect',
        class: 'bbox'
      g.appendChild text = dom.create 'text'
    else
      g = wrapper.firstChild
      [rect, text] = g.childNodes
    dom.attr g,
      transform: "translate(#{obj.pts[0].x},#{obj.pts[0].y})"
    dom.attr text,
      fill: obj.color
      style: "font-size:#{obj.fontSize}px" +
        if obj.opacity? then ";opacity:#{obj.opacity}" else ''
    if not options? or options.text or options.fontSize or options.color or options.opacity
      ## Remove any leftover TeX expressions
      svgG.remove() while (svgG = g.lastChild) != text
      @texDelete id if @texById[id]?
      content = obj.text
      input = document.getElementById 'textInput'
      ## Extract $math$ and $$display math$$ expressions.
      ## Based loosely on Coauthor's `replaceMathBlocks`.
      readyJobs = []
      maths = []
      latex = (text) =>
        cursorRE = '<tspan\\s+class="cursor">[^<>]*<\\/tspan>'
        mathRE = /// \$(#{cursorRE})\$ | \$\$? | \\. | [{}] ///g
        math = null
        while (match = mathRE.exec text)?
          if math?
            switch match[0]
              when '{'
                math.brace++
              when '}'
                math.brace--
                math.brace = 0 if math.brace < 0  # ignore extra }s
              #when '$', '$$'
              else
                if match[0].startsWith('$') and math.brace <= 0
                  math.formulaEnd = match.index
                  math.end = match.index + match[0].length
                  math.suffix = match[1]
                  maths.push math
                  math = null
          else if match[0].startsWith '$'
            math =
              display: match[0].length > 1
              start: match.index
              formulaStart: match.index + match[0].length
              brace: 0
              prefix: match[1]
        if maths.length
          @texById[id] = jobs = []
          out = [text[...maths[0].start]]
          for math, i in maths
            math.formula = text[math.formulaStart...math.formulaEnd]
            .replace ///#{cursorRE}///, (match) ->
              out.push match
              ''
            math.formula = dom.unescape math.formula
            out.push math.prefix if math.prefix?
            out.push "$MATH#{i}$"
            out.push math.suffix if math.suffix?
            math.out = """<tspan data-tex="#{dom.escapeQuote math.formula}" data-display="#{math.display}">&VeryThinSpace;</tspan>"""
            if i < maths.length-1
              out.push text[math.end...maths[i+1].start]
            else
              out.push text[math.end..]
            attrs =
              color: obj.color
              fontSize: obj.fontSize
              opacity: obj.opacity
            if (job = @tex[[math.formula, math.display]])?
              unless job.texts[id]?
                job.texts[id] = attrs
                jobs.push job
                readyJobs.push {job, id} if job.svg? # already rendered
            else
              job = @tex[[math.formula, math.display]] =
                formula: math.formula
                display: math.display
                texts: "#{id}": attrs
              @texQueue.push job
              jobs.push job
              if @texQueue.length == 1  # added job while idle
                @texInit()
                @texJob()
          out.join ''
        else
          text
      ## Basic Markdown support based on CommonMark and loosely on Slimdown:
      ## https://gist.github.com/jbroadway/2836900
      markdown = (text) ->
        ## See https://spec.commonmark.org/0.29/#code-spans
        text = text
        .replace /(^|[^\\`])(`+)((?!`)[^]*?[^`])\2(?!`)/g, (m, pre, left, inner) ->
          ## Strip one leading and trailing space
          inner = inner[1..] if inner.startsWith '\u00a0'
          inner = inner[...-1] if inner.endsWith '\u00a0'
          "#{pre}<tspan class='code'>#{inner.replace /[`*_~$]/g, '\\$&'}</tspan>"
        text = latex text
        .replace ///
          (^|[\s!"#$%&'()*+,\-./:;<=>?@\[\]^_`{|}~])  # omitting \\
          (\*+|_+)(\S(?:[^]*?\S)?)\2
          (?=$|[\s!"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~])
        ///g, (m, pre, left, inner) ->
          ## GFM supports ***bold italic***, and uses a parity rule for >3 *s
          classes = []
          classes.push 'strong' if left.length > 1
          classes.push 'emph' if left.length % 2 == 1
          "#{pre}<tspan class='#{classes.join ' '}'>#{inner}</tspan>"
        .replace ///
          (^|[\s!"#$%&'()*+,\-./:;<=>?@\[\]^_`{|}~])  # omitting \\
          (~~)(\S(?:[^]*?\S)?)\2
          (?=$|[\s!"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~])
        ///g, (m, pre, left, inner) ->
          "#{pre}<tspan class='strike'>#{inner}</tspan>"
        .replace /\\([!"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~])/g, "$1"
        .replace /\$MATH(\d+)\$/g, (match, i) ->
          maths[i].out
        ## Multiline support: if text has newlines, split into multiple <tspan>s
        ## that duplicate font changes as necessary.  Add a space to blank lines
        ## to ensure that they render (SVG doesn't render blank <tspan>s).
        if 0 <= text.indexOf '\n'
          tspans = []  # currently unclosed font-changing <tspan>s
          text = (
            for line, i in text.split '\n'
              resume = tspans.join ''
              ## Find newly opened <tspan>s, and closing </tspan>s,
              ## by first removing all <tspan>s closed within the line.
              unmatched = line
              loop
                oldUnmatched = unmatched
                unmatched = unmatched.replace ///<tspan[^<>]*>.*?</tspan>///, ''
                break if unmatched == oldUnmatched
              unmatched.replace ///</tspan>///g, ->
                tspans.pop()
                ''
              unmatched.replace ///<tspan[^<>]*>///g, (match) ->
                tspans.push match
                ''
              line = resume + line + ("</tspan>" for tspan in tspans).join '' # eslint-disable-line coffee/no-unused-vars
              line = """<tspan x="0" dy="1.25em">#{line or '&nbsp;'}</tspan>""" unless i == 0
              line
          ).join '\n'
        text
      if id == pointers.text
        input = document.getElementById 'textInput'
        cursor = input.selectionStart
        if input.value != content  # newer text from server (parallel editing)
          ## If suffix starting at current cursor matches new text, then move
          ## cursor to start at new version of suffix.  Otherwise leave as is.
          suffix = input.value[cursor..]
          if suffix == content[-suffix.length..]
            cursor = content.length - suffix.length
          input.value = content
          setTimeout ->
            input.selectionStart = input.selectionEnd = cursor
          , 0
        content = dom.escape(content[...cursor]) +
                  '<tspan class="cursor">&VeryThinSpace;</tspan>' +
                  dom.escape(content[cursor..])
        g.appendChild pointers.cursor = dom.create 'line',
          class: 'cursor'
          ## 0.05555 is actual size of &VeryThinSpace;, 2 is to exaggerate
          'stroke-width': 2 * 0.05555 * obj.fontSize
          ## 1.2 is to exaggerate
          y1: -0.5 * 1.2 * obj.fontSize
          y2:  0.5 * 1.2 * obj.fontSize
        setTimeout pointers.cursorUpdate = ->
          return unless pointers.cursor?
          bbox = text.querySelector('tspan.cursor').getBBox()
          x = bbox.x + 0.5 * bbox.width
          y = bbox.y + 0.5 * bbox.height
          dom.attr pointers.cursor, transform: "translate(#{x} #{y})"
        , 0
      else
        content = dom.escape content
      content = markdown content
      text.innerHTML = content
      for {job, id} in readyJobs
        @texRender job, id
    ## Update bounding box of text
    x = y = width = height = 0
    dom.attr rect, {x, y, width, height}
    {x, y, width, height} = g.getBBox()
    dom.attr rect, {x, y, width, height}
    wrapper
  texInit: ->
    return if @tex2svg?
    if Meteor.settings.public.tex2svg
      @tex2svg = new Worker window.URL.createObjectURL new Blob ["""
        importScripts(#{JSON.stringify Meteor.settings.public.tex2svg});
      """], type: 'text/javascript'
    else
      @tex2svg = new Worker '/tex2svg.js'
    @tex2svg.onmessage = (e) =>
      return if @stopped
      {formula, display, svg} = e.data
      job = @tex[[formula,display]]
      unless job?
        return console.warn "No job for #{formula},#{display}"
      unless formula == job.formula and display == job.display
        console.warn "Mismatch between #{formula},#{display} and #{job.formula},#{job.display}"
      exScale = 0.523
      exScaler = (match, dimen, value) ->
        "#{dimen}=\"#{job[dimen] = exScale * parseFloat value}\""
      job.depth = 0  # default if no vertical-align specification
      svg = svg
      .replace /\b(width)="([\-\.\d]+)ex"/, exScaler
      .replace /\b(height)="([\-\.\d]+)ex"/, exScaler
      .replace /\bvertical-align:\s*([\-\.\d]+)ex/, (match, depth) ->
        job.depth = -parseFloat depth
        ''
      ## Background rectangles for error messages: fill transparent red
      .replace /<rect\s+data-background="true"/g, "$& fill=\"#f888\""
      ## Remove unneeded data attributes (MathML)
      .replace /\bdata-[\w\-]*=(?:"[^"]*"|'[^']*')\s*|\bstyle=""\s*/g,
        (match, offset, string) ->
          if inTag string, offset
            ''
          else
            match
      .replace /\s+>/g, '>'
      .replace /<defs><\/defs>/g, ''
      job.svg = svg
      for id of job.texts
        @texRender job, id
      @texJob()
  texRender: (job, id) ->
    ###
    Render all instances of `job` within text object with ID `id`.
    Precondition: `job.texts[id]` should exist.

    `job.texts[id]` can be one of two values:
      * object containing `color`, `fontSize`, and `opacity` attributes,
        meaning "needs to be rendered with these attributes"
      * array of rendered <g> elements, one for each instance of `job`
        (in the order they appear in the text)
    This method only does work in the first case.
    ###
    {color, fontSize, opacity} = job.texts[id]
    return unless fontSize?
    g = @dom[id].firstChild
    [rect, text] = g.childNodes
    dx = job.width * fontSize
    ## Roboto Slab in https://opentype.js.org/font-inspector.html:
    unitsPerEm = 1000 # Font Header table
    #descender = 271   # Horizontal Header table
    ascender = 1048   # Horizontal Header table
    job.texts[id] =
      for tspan in text.querySelectorAll """tspan[data-tex="#{CSS.escape job.formula}"][data-display="#{job.display}"]"""
        dom.attr tspan, {dx}
        tspanBBox = tspan.getBBox()
        g.appendChild svgG = dom.create 'g'
        svgG.innerHTML = job.svg
        .replace /currentColor/g, color
        x = tspanBBox.x - dx + tspanBBox.width/2  # divvy up &VeryThinSpace;
        y = tspanBBox.y \
          #+ tspanBBox.height * (1 - descender/(descender+ascender)) \
          + fontSize * (ascender / unitsPerEm) \
          - job.height * fontSize + job.depth * fontSize / 2
          # not sure where the /2 comes from... exFactor?
        dom.attr svgG,
          transform: "translate(#{x} #{y}) scale(#{fontSize})"
          style: "opacity:#{opacity}" if opacity?
        svgG
    ## The `dx` attributes set above may mean that previously rendered LaTeX
    ## <g>s need to shift horizontally.  Update their x translation.
    for job2 in @texById[id]
      continue if job == job2  # don't need to update job we just rendered
      continue if job2.texts[id].fontSize?  # only update already rendered jobs
      for tspan, i in text.querySelectorAll """tspan[data-tex="#{CSS.escape job2.formula}"][data-display="#{job2.display}"]"""
        tspanBBox = tspan.getBBox()
        x = tspanBBox.x - tspan.getAttribute('dx') + tspanBBox.width/2  # divvy up &VeryThinSpace;
        svgG = job2.texts[id][i]
        svgG.setAttribute 'transform', svgG.getAttribute('transform').replace \
          /translate\([\-\.\d]+/, "translate(#{x}"
    ## Update bounding box of text
    x = y = width = height = 0
    dom.attr rect, {x, y, width, height}
    {x, y, width, height} = g.getBBox()
    dom.attr rect, {x, y, width, height}
    ## Update selected copies
    @updated id
    pointers.cursorUpdate?() if id == pointers.text
  texJob: ->
    return unless @texQueue.length
    @tex2svg.postMessage @texQueue.shift()
  renderImage: (obj, options) ->
    id = @id obj
    unless (image = @dom[id])?
      @root.appendChild @dom[id] = image =
        dom.create 'image', null, dataset: id: id
      #image.onload = (e) -> console.log 'loaded'
      image.onerror = (e) =>
        return if image.getAttribute('href').startsWith 'data:' # avoid looping
        dom.attr image, href: icons.dataUrl \
          icons.svgIcon 'exclamation-rect',
            width: '64px'
            height: '64px'
        @updated id
    dom.attr image,
      x: obj.pts[0].x
      y: obj.pts[0].y
      style: "opacity:#{obj.opacity}" if obj.opacity?
    if not options? or options.url or options.proxy or options.credentials
      dom.attr image,
        href: if obj.proxy then proxyUrl obj.url else obj.url
        crossorigin: if obj.credentials then 'use-credentials' else 'anonymous'
    image
  render: (obj, options) ->
    ## `options` should be an object mapping changed keys of `obj` to `true`,
    ## or absent (`undefined`, not `{}`), meaning `obj` is brand new.
    transformOnly = options? and options.start == obj.pts.length
    for key, changed of options
      if changed and key not in ['tx', 'ty', 'start']
        transformOnly = false
        break
    elt =
      if transformOnly
        @dom[@id obj]
      else
        switch obj.type
          when 'pen'
            @renderPen obj, options
          when 'poly'
            @renderPoly obj, options
          when 'rect'
            @renderRect obj, options
          when 'ellipse'
            @renderEllipse obj, options
          when 'text'
            @renderText obj, options
          when 'image'
            @renderImage obj, options
          else
            console.warn "No renderer for object of type #{obj.type}"
    if (not options? or options.tx or options.ty) and elt?
      if obj.tx? or obj.ty?
        elt.setAttribute 'transform', "translate(#{obj.tx ? 0} #{obj.ty ? 0})"
      else
        elt.removeAttribute 'transform'
    id = @id obj
    @updated id, transformOnly
    @renderAnchors id, obj if @anchors?
    ## DBVT update
    #unless @bbox[id]?  # new object
    #  @dbvt.insert id, @bbox[id] =
    #    dom.svgBBox @board.svg, elt, @board.root
    #else  # update object
    #  if obj.type == 'pen' and not (options.width or options.tx or options.ty)
    #    # only points are added
    #    bbox = @bbox[id]
    #    for i in [options.start...obj.pts.length]
    #      {x, y} = obj.pts[i]
    #      x += obj.tx if obj.tx?
    #      y += obj.ty if obj.ty?
    #      bbox = bbox.union (BBox.fromPoint {x, y}).fattened (obj.width / 2)
    #  else
    #    bbox = dom.svgBBox @board.svg, elt, @board.root
    #  @bbox[id] = bbox
    #  @dbvt.move id, bbox
    ## BBox update (alternative to DBVT)
    if obj.type == 'pen' and options?.start? and
       not (options.width or options.tx or options.ty)  # only points are added
      unless options.start == obj.pts.length
        @bbox[id] = @bbox[id].union(
          BBox.fromPoints obj.pts[options.start...obj.pts.length]
          .translate obj.tx ? 0, obj.ty ? 0
          .fattened obj.width / 2
        )
        if obj.arrowStart and (line = elt.querySelector '[marker-start]')?
          @bbox[id] = @bbox[id].union dom.svgBBox @board.svg, line, @board.root
        if obj.arrowEnd and (line = elt.querySelector '[marker-end]')?
          @bbox[id] = @bbox[id].union dom.svgBBox @board.svg, line, @board.root
    else
      @bbox[id] = dom.svgBBox @board.svg, elt, @board.root
  delete: (obj, noWarn) ->
    id = @id obj
    unless @dom[id]?
      console.warn "Attempt to delete unknown object ID #{id}?!" unless noWarn
      return
    @dom[id].remove()
    delete @dom[id]
    delete @bbox[id]
    #@dbvt.remove id
    tools.text.stop() if id == pointers.text
    @texDelete id if @texById[id]?
    @updated id
    @renderAnchors id if @anchors?[id]?
  texDelete: (id) ->
    for job in check = @texById[id]
      delete job.texts[id]
    delete @texById[id]
    ## After we potentially rerender text, check for expired cache jobs.
    ## Wait 5 seconds in case we're going to use the text again soon
    ## (e.g. when switching views in history).
    setTimeout =>
      for job in check
        unless (t for t of job.texts).length
          delete @tex[[job.formula, job.display]]
    , 5000
  #has: (obj) ->
  #  (id obj) of @dom
  shouldNotExist: (obj) ->
    ###
    Call before rendering a should-be-new object.  If already exists, log a
    warning and clear the object from the map so a new one will get created.
    Currently the old object stays in the DOM, though.
    ###
    id = @id obj
    if id of @dom
      console.warn "Duplicate object with ID #{id}?!"
      delete @dom[id]
  updated: (id, transformOnly) ->
    if @board.selection?.has id
      if (elt = @dom[id])?
        @board.selection.redraw id, elt, transformOnly
      else
        @board.selection.remove id
    @board.highlighters[id]?.clear()

  ## Anchors
  renderAnchors: (id, obj) ->
    unless obj?  # deletion
      for anchor in @anchors[id] ? []
        anchor.remove()
      delete @anchors[id]
    else
      return unless anchorObjectTypes.has obj.type
      @anchors[id] ?= []
      for anchor, index in anchorsOf obj
        unless (rect = @anchors[id][index])?
          @root.appendChild rect = @anchors[id][index] = dom.create 'rect',
            class: 'anchor'
            width: 2 * anchorRadius
            height: 2 * anchorRadius
            'stroke-width': anchorStroke
            'data-obj': id
            'data-index': index
        dom.attr rect,
          x: anchor.x - anchorRadius
          y: anchor.y - anchorRadius
  showAnchors: (show) ->
    if show
      @anchors ?= {}
      for id of @dom ? {}
        obj = @board.findObject id
        continue unless obj?
        @renderAnchors id, obj
    else
      for id of @anchors ? {}
        @renderAnchors id
      @anchors = null

###
dot = (obj, p) ->
  dom.create 'circle',
    cx: p.x
    cy: p.y
    r: obj.width * p.w / 2
    fill: obj.color
edge = (obj, p1, p2) ->
  dom.create 'line',
    x1: p1.x
    y1: p1.y
    x2: p2.x
    y2: p2.y
    stroke: obj.color
    'stroke-opacity': obj.opacity
    #'stroke-width': obj.width * (p1.w + p2.w) / 2
    'stroke-width': obj.width * p2.w
    ## Replace `dot` with round linecap, now set in CSS.
    #'stroke-linecap': 'round'
    ## Dots mode:
    #'stroke-width': 1
###

inTag = (string, offset) ->
  ## Copied from Coauthor.
  ## Known issue: `<a title=">"` looks like a terminated tag to this code.
  open = string.lastIndexOf '<', offset
  if open >= 0
    close = string.lastIndexOf '>', offset
    if close < open  ## potential unclosed HTML tag
      return true
  false
