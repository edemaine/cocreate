# Cocreate

**Cocreate** is a web-based shared whiteboard tool for drawing, teaching, and
brainstorming together with others.

![Cocreate screenshot](http://erikdemaine.org/software/cocreate_large.png)

## Features

Here is a summary of the main features of Cocreate.
Features marked with <sup>★</sup> are rare among shared whiteboard tools.

* Instantly create a new board and share the URL to draw together with others.
  **No accounts required**<sup>★</sup>.
* Works on computers, tablets, and phones **without any software installation**
  (use any modern web browser, such as Chrome)
* **See everyone's cursors**, with their names and what page they're on,
  updated live
  * **Jump to someone's cursor**<sup>★</sup> from list of users
* See everyone's drawing **while they draw**<sup>★</sup>
  * **Freehand pen** drawing, with **pressure sensitivity**<sup>★</sup>
    for supporting devices (e.g., Wacom, Surface, iPad Pencil)
  * Separation of pen, touch, and mouse inputs<sup>★</sup>: disable drawing via touch
  * Basic drawing tools, in particular for cleaner mouse input:
    line segments, rectangles/squares, ellipses/circles,
    including easy dots<sup>★</sup>
  * **Text** tool with **LaTeX math**<sup>★</sup> support
    (via [MathJax](https://www.mathjax.org/); see
     [supported commands](https://github.com/edemaine/tex2svg-webworker#supported-latex-commands))
    and basic **Markdown formatting**<sup>★</sup>
  * **Image** (PNG/JPG/GIF/SVG) embedding from other websites
    (e.g., Imgur or Coauthor) for drawing on top of images
  * Other basic tools: pan, zoom, zoom to fit<sup>★</sup>, eraser
  * Basic settings: line thickness (scaling correctly with zoom),
    opacity<sup>★</sup>, color palette, fill, font size
* **Vector** representation:
  * **Select, edit, move, duplicate<sup>★</sup>, delete** existing objects,
    including **rectangular select**<sup>★</sup>
  * **Copy/paste**, including between pages or boards, and copying from the
    past and pasting into the present<sup>★</sup>
  * Export as **SVG**<sup>★</sup>
* **Multiple pages**<sup>★</sup>
  * **Page duplication**<sup>★</sup> (for separating ideas/alternatives,
    animation, and efficiency)
  * Can link to specific pages<sup>★</sup>
  * **Grid** backgrounds: **Square** and **triangular**<sup>★</sup>
    with optional **grid snapping**<sup>★</sup> and
    **half-grid snapping**<sup>★</sup>
* **Undo/redo** (of your own operations)
* **Time travel**<sup>★</sup> to see entire past history of the board
  (and copy/paste to present)
* **Keyboard shortcuts**<sup>★</sup>
* **Minimalist** user interface leaves lots of room for drawing,
  without hiding features behind dropdowns,
  while tooltips explain the many buttons
  * **Dark mode**<sup>★</sup>
* **Free/open source**<sup>★</sup> ([MIT license](LICENSE))
* Via [Comingle](https://github.com/edemaine/comingle),
  you can have one interface with both your video conference and
  your shared Cocreate drawing (and any other web tools).

To see what's changed in Cocreate recently, check out the
[Changelog](CHANGELOG.md).

There are
[plans for many more features](https://github.com/edemaine/cocreate/issues).
Short-term goals include:

* [Re-ordering/archiving pages](https://github.com/edemaine/cocreate/issues/137)
* [Resizing objects](https://github.com/edemaine/cocreate/issues/17)

Feel free to help by submitting a pull request!

## [User Guide](doc/README.md)

Want to know how to get started or how to use the features listed above?
[Read our user guide](doc/README.md).

## [Installation](INSTALL.md)

To run your own Cocreate server, see
[detailed installation instructions](INSTALL.md).
