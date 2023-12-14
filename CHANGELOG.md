# Changelog

This file describes significant changes to Cocreate to an audience of
both everyday users and administrators running their own Cocreate server.
To see every change with descriptions aimed at developers, see
[the Git log](https://github.com/edemaine/cocreate/commits/main).
As a continuously updated web app, Cocreate uses dates
instead of version numbers.

## 2023-12-14

* Improve SVG export font embedding
  * Include `unicode-range`, which otherwise caused issues when embedding
    in Firefox.  This makes exported files slightly bigger.
  * Include CSS rules only for needed fonts and unicode-ranges.
    This makes typical exported files smaller.

## 2023-12-11

* Fix PDF export with certain mathematical expressions, e.g.,
  `$\log_2 n$`.

## 2023-11-24

* Light/dark mode now initializes to the user's preference according to the
  browser/OS.  (Previously it defaulted to light.)

## 2023-11-13

* Fix zero-length arrows, in particular fixing crash on Firefox

## 2023-11-03

* Fix arrowheads getting clipped when downloading SVG/PDF,
  and rectangular selection of arrowheads.
  [[#225](https://github.com/edemaine/cocreate/issues/225)]

## 2023-11-01

* Fix dragging multiple anchors of a polyline object
  [[#226](https://github.com/edemaine/cocreate/issues/226)]

## 2023-08-09

* New polygonal line tool!
  [[#35](https://github.com/edemaine/cocreate/issues/35)]
* Reduce zoom speed via <kbd>Ctrl</kbd> + mouse wheel by 4x
* Fix PDF export of LaTeX text and arrows

## 2023-05-01

* Anchor drag now translates text and images when selecting their origins.
  [[#221](https://github.com/edemaine/cocreate/issues/221)]

## 2023-04-08

* Dark mode better preserves color saturation using new SVG color filter
  from [Dark Reader](https://darkreader.org/)'s Filter+ mode.

## 2023-01-20

* Fix SVG export of pen strokes with arrows.

## 2022-11-28

* Drawing actions are no longer interrupted when your cursor accidentally
  leaves the Cocreate window.
  [[#219](https://github.com/edemaine/cocreate/issues/219)]
* Moving your cursor into the Cocreate window while you have a button pressed
  no longer starts a drawing action, fixing behavior on e.g. Chromium on X11
  with a stylus.
  [[#218](https://github.com/edemaine/cocreate/issues/218)],
  [[#219](https://github.com/edemaine/cocreate/issues/219)]

## 2022-11-21

* Fix anchor drag bugs: dragging non-defining corners of rectangles and
  ellipses was broken, and moving to old location was accidentally forbidden.
  [[#214](https://github.com/edemaine/cocreate/issues/214)]
* Fix dotted rectangles not rendering

## 2022-11-17

* Arrowheads now work with pen tool
  [[#35](https://github.com/edemaine/cocreate/issues/35)]
* Arrowhead bug fixes
* Selecting text objects (only) shows font size attribute
  [[#117](https://github.com/edemaine/cocreate/issues/117)]

## 2022-11-16

* Dashed and dotted line styles for pen, segments, rectangles, and ellipses
  [[#61](https://github.com/edemaine/cocreate/issues/61)]

## 2022-11-14

* New start/end arrowhead support for line segments
  [[#35](https://github.com/edemaine/cocreate/issues/35)]
* Bug fix in rectangular selection of anchors with translated objects.

## 2022-11-13

* New anchor select tool now supports selecting multiple anchors,
  similar to the regular select tool:
  Click/tap on individual anchors while holding <kbd>Shift</kbd>
  to toggle their selection, or drag a selection rectangle.
  Then move the selected anchors by dragging or using arrow keys.
  The <kbd>Escape</kbd> key clears the selection.
  [[#214](https://github.com/edemaine/cocreate/issues/214)]

## 2022-11-12

* New "anchor select" tool with basic support for dragging anchors
  to reshape segments, rectangles, and ellipses.
  [[#214](https://github.com/edemaine/cocreate/issues/214)]

## 2022-08-08

* Fix bug in vertical alignment of text with LaTeX formulas in Firefox.
  [[#199](https://github.com/edemaine/cocreate/issues/199)]

## 2022-06-14

* Fix bug in Download PDF messing up Cocreate's layout.

## 2022-06-02

* Cocreate's math renderer no longer includes the `physics` package.
  This fixes e.g. LaTeX's standard `\div`, but removes some features.
  [[#208](https://github.com/edemaine/cocreate/issues/208)]

## 2022-05-25

* Arrow keys nudge selected objects by grid units
  (or half-grid units while holding <kbd>Shift</kbd>).
  [[#149](https://github.com/edemaine/cocreate/issues/149)]
* <kbd>Escape</kbd> key now deselects any selected objects.
  [[#179](https://github.com/edemaine/cocreate/issues/179)]
* Fixed dragging of current selection accidentally selecting an object
  (when the object was under the initial drag point).
* Improve "Cocreate updated" message.
  [[#200](https://github.com/edemaine/cocreate/issues/200)]

## 2022-05-19

* New "Download PDF file" feature downloads page or selection in PDF format.
  [[#98](https://github.com/edemaine/cocreate/issues/98)]

## 2022-05-09

* Dragging objects with grid snapping is now more accurate.
  The previous behavior could leave your cursor feeling off by nearly one cell.
  [[#206](https://github.com/edemaine/cocreate/issues/206)]
* Other users' cursors now have a drop shadow to distinguish from
  the drawing underneath them.
* User list automatically closes after clicking outside the list.
* Fix Firefox support for <kbd>Ctrl+C</kbd> copying objects as SVG into the
  clipboard for e.g. pasting into Inkscape.  Images won't be inlined though.
  Also Chrome [doesn't support this yet](https://bugs.chromium.org/p/chromium/issues/detail?id=1110511).

## 2022-05-08

* In select mode, double-clicking on a text object switches to text mode,
  so you can easily modify the content (similar to Inkscape).
* Fix clicking on the selected text object in text mode causing deselection.

## 2022-05-03

* Clock synchronization between client and server (used for cursor fading)
  is more accurate (median of 3, which helps especially when (re)connecting)
  and runs less frequently (every 30 minutes, to reduce server load).

## 2022-04-28

* User list now appears with explanatory message if no other users.
* Fix missing arrows on tooltips/popups.

## 2022-04-25

* You can now jump to the cursor of another user by clicking the users icon
  next to your name, then clicking on a name.
  [[#136](https://github.com/edemaine/cocreate/issues/136)]
* Add tooltip explaining the "Your Name" text entry box.
* Fix updating of names for remote cursors.

## 2022-04-21

* Cocreate will now tell you when it's disconnected from the server
  (because of either network or server failure), and will ask you before
  upgrading to a new version of Cocreate.
  This should help avoid losing work because of server restarts.
  [[#200](https://github.com/edemaine/cocreate/issues/200)]
* Local cursor now accurately reflects your current fill color/mode
  (in relevant drawing modes)

## 2022-04-16

* Some LaTeX features were previously hidden behind a `\require` command.
  Now there's an explicit
  [list of supported commands and extensions](https://github.com/edemaine/tex2svg-webworker#supported-latex-commands).

## 2022-04-12

* When LaTeX text has errors, Cocreate will now render the LaTeX source
  (with a transparent red background) instead of the error message,
  making it easier to read text while it's being written.
  You can hover over the text to see the error message.
  [[#202](https://github.com/edemaine/cocreate/issues/202)]
* Cocreate removes some unneeded attributes in SVG produced by MathJax,
  so exported SVG with LaTeX should be smaller.
* Cocreate is now built on [SolidJS](https://www.solidjs.com/) instead of
  React, improving UI reactivity.

## 2022-03-23

* Triangular half-grid snapping now includes triangle centers.
  [[#21](https://github.com/edemaine/cocreate/issues/21)]

## 2022-03-22

* Dots are now easy to draw by clicking (without dragging) with the Ellipse or
  Rectangle tool, making small circles or squares centered at the click point.
  Dots can be colored and/or filled.
  The dot size is proportional to the line width.
  [[#175](https://github.com/edemaine/cocreate/issues/175)]
* New experimental half-grid snapping feature.  This doesn't change the grid
  visually, but lets you snap to half-grid positions.
  [[#21](https://github.com/edemaine/cocreate/issues/21)]

## 2022-03-20

* Multitouch pan/zoom in pan mode, and in drawing modes when
  "drawing with touch" is disabled.
  [[#13](https://github.com/edemaine/cocreate/issues/13)]
  [[#111](https://github.com/edemaine/cocreate/pull/111)]
* New rectangular selection algorithm works on Firefox and avoids false
  matches: selection rectangle checks overlap with shape itself,
  not (just) its bounding box.
  [[#87](https://github.com/edemaine/cocreate/pull/87)]
  [[#183](https://github.com/edemaine/cocreate/pull/183)]

## 2022-03-18

* Selecting, dragging, and deleting many objects at once is much faster now.
  [[#196](https://github.com/edemaine/cocreate/pull/196)]
* Support dragging images from other pages into Cocreate, creating image link
  (previously, only dragging links to image URLs worked).
* Fix rendering of zero-width/height rectangles and ellipses in Chrome.
  [[#198](https://github.com/edemaine/cocreate/pull/198)]

## 2022-03-16

* Fix LaTeX rendering in Time Travel view.
* Speed up time travel by large temporal distances.

## 2021-09-14

* Fix paste and duplicate not working.

## 2021-09-12

* Partial transparency/opacity attribute for all objects / drawing modes.
  [[#193](https://github.com/edemaine/cocreate/pull/193)]

## 2021-07-14

* Improved LaTeX rendering via MathJax 3.2.0

## 2021-06-09

* Fix Cocreate on iPads with Pencil's Scribble feature enabled.
  [[#157](https://github.com/edemaine/cocreate/issues/158)]

## 2021-06-02

* Triangular grid feature, including reasonable snapping behavior
  [[#21](https://github.com/edemaine/cocreate/issues/21)]
* Avoid one-dimensional ellipses and rectangles when holding <kbd>Shift</kbd>.

## 2021-06-01

* Support incognito mode by handling lack of localStorage

## 2021-05-30

* Default line width changed from 5 to 3.
  This is better for pen drawing, and gives more room to grow.
  [[#172](https://github.com/edemaine/cocreate/issues/172)]
* Fix drawing horizontal and vertical lines by holding <kbd>Shift</kbd>.
  [[#187](https://github.com/edemaine/cocreate/issues/187)]
* Prevent <kbd>Ctrl-D</kbd> from bookmarking page when using Select tool, even
  if duplicating an empty selection.  (Other tools can still trigger bookmark.)
  [[#186](https://github.com/edemaine/cocreate/issues/186)]

## 2021-05-06

* Fix <kbd>Alt</kbd> key behavior when drawing rectangles, ellipses,
  and segments
  [[#182](https://github.com/edemaine/cocreate/issues/182)]
* Fix pan tool when clicking on grid lines
  [[#180](https://github.com/edemaine/cocreate/issues/180)]

## 2021-04-30

* Fix SVG export with mixture of text and math

## 2021-04-28

* You can now link to a specific page of a Cocreate board.  You can copy the
  link location (or open a new tab) by right clicking on a page button.
  The webpage URL also automatically updates when you click on a page button.
  [[#164](https://github.com/edemaine/cocreate/issues/164)]
* Cocreate now remembers the last page you viewed on each board, and starts
  there if the URL didn't specify a specific page to start on.  (This is useful
  in the context of Comingle, where the entry URL usually remains fixed.)

## 2021-04-26

* Custom scrollbars should look nicer especially in dark mode.

## 2021-04-25

* You can now drag the selection by dragging from anywhere within the
  selection rectangle, making it much easier to drag the current selection.
  <kbd>Shift</kbd>-clicking behaves as before (toggle an item or start a
  toggle rectangle), so you can still easily modify the selection.
  [[#170](https://github.com/edemaine/cocreate/issues/170)]
* You can now select a text object (e.g., to edit it with the text tool)
  by clicking anywhere within its bounding box, instead of having to click
  exactly on the letters.
  [[#171](https://github.com/edemaine/cocreate/issues/171)]
* You can now pan the page around without switching to Pan mode
  by dragging with the middle mouse button (in addition to the previous
  method of dragging while holding <kbd>Spacebar</kbd>).
  [[#174](https://github.com/edemaine/cocreate/issues/178)]
* Exported SVG files should be slightly smaller.
* Middle click shouldn't accidentally paste on Linux anymore.
  [[#166](https://github.com/edemaine/cocreate/issues/166)]

## 2021-04-24

* Time Travel is now a toggle/overlay mode supporting both Pan and Select
  tools, enabling copying from the past and pasting into the present.
  [[#174](https://github.com/edemaine/cocreate/issues/174)]
* Pen strokes render more efficiently, especially when not using a
  pressure-sensitive pen, so should bog down a page less.
* Rename main branch from `master` to `main`.  The link to the documentation
  and this Changelog have changed (but the old links redirect).

## 2021-03-30

* Exported SVG with images should now load correctly in Inkscape
  (by replacing `href` attribute with older `xlink:href`).
  [[#165](https://github.com/edemaine/cocreate/issues/165)]

## 2021-03-29

* Cocreate now remembers the last view you used for each page of each board
  in localStorage, and resets the view when going to a new page.
  [[#163](https://github.com/edemaine/cocreate/issues/163)]
* The "zoom-1" reset button now reset the entire view, returning to the origin
  in addition to the old behavior of resetting the zoom to 100%.
* Rendering the page grid is no longer extremely slow if you zoom way out.
  [[#163](https://github.com/edemaine/cocreate/issues/163)]
  [[#21](https://github.com/edemaine/cocreate/issues/21)]
* Fix zoom-to-fit button.  (It was doing the wrong thing when zoom level was
  not 100% and page contained text objects.)
* Fix zoom to avoid under/overflows
  [[#163](https://github.com/edemaine/cocreate/issues/163)]

## 2021-03-17

* Allow typing or pasting a <kbd>Tab</kbd> character when entering text.
  It renders as an em-space.
  [[#160](https://github.com/edemaine/cocreate/issues/160)]

## 2021-02-20

* Improve handling of `` ` `` characters in text, closer to the Markdown spec.

## 2021-02-16

* Restore the grid in SVG export
  [[#157](https://github.com/edemaine/cocreate/issues/157)]

## 2021-02-11

* Improve styling of list of users in page tooltip.

## 2021-02-09

* Fix CORS support for API calls.
* Fix Coop protocol support for setting of dark mode.

## 2021-02-07

* Increase height of text entry box to be enough for two lines
  (50% increase), in particular to clarify that it supports multiple lines.
* Make it easier to resize the text entry box by preventing it from getting
  too small vertically and preventing horizontal changes.
* Support blank lines in multiline text objects.

## 2021-02-06

* Pages gain a hover tooltip with a list of all users on that page.
* Fix long-standing issue with extra lines being drawn in Time Travel view.
* Fix undo/redo buttons for stepping through history one operation at a time.

## Older Changes

Refer to [the Git log](https://github.com/edemaine/cocreate/commits/main)
for changes older than listed in this document.
