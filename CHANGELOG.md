# Changelog

This file describes significant changes to Cocreate to an audience of
both everyday users and administrators running their own Cocreate server.
To see every change with descriptions aimed at developers, see
[the Git log](https://github.com/edemaine/cocreate/commits/main).
As a continuously updated web app, Cocreate uses dates
instead of version numbers.

## 2021-09-12

* Partial transparency/opacity attribute for all objects / drawing modes.
  [[#193](https://github.com/edemaine/coauthor/pull/193)]

## 2021-07-14

* Improved LaTeX rendering via MathJax 3.2.0

## 2021-06-09

* Fix Cocreate on iPads with Pencil's Scribble feature enabled.
  [[#157](https://github.com/edemaine/coauthor/issues/158)]

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
