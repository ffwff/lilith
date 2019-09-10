# missio

Lilith's package manager.

## Supported packages

### Core packages

*(packages that are made in-house)*

 * **adam**: primary shell for the system
 * **base**: directory structure for the system's root
 * **core**: core utilities
 * **gfx**: graphics demo
 * **wm**: window manager demo and assorted applications

#### Libraries

 * **libc**: c library

### Ported packages

*(ported packages with varying degrees of stability)*

 * **kilo**: terminal text editor
 * **mruby**: embedded ruby implementation

#### Libraries

 * **libcairo**: cairo graphics library

   compiles but diagonal lines can't be drawn and built-in fonts don't work
 * **libgc**: garbage collector library (untested)
 * **libpixman**: pixman library (used by cairo)
 * **libpng**: png library (used by cairo)
 * **libz**: data compression library (used by cairo)
