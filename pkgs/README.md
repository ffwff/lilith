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
 * **libcanvas**: single-header canvas library
 * **libwm**: window manager server/client

### Ported packages

*(ported packages with varying degrees of stability)*

 * **kilo**: terminal text editor
 * **mruby**: embedded ruby implementation
 * **lua**: lua implementation

#### Libraries

 * **libcairo**: cairo graphics library

   runs but needs some deoptimization hacks to work correctly
 * **libgc**: garbage collector library

   compiles but doesn't work
 * **libpixman**: pixman library (used by cairo)
 * **libpng**: png library (used by cairo)
 * **libz**: data compression library (used by cairo)
