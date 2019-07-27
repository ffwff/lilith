# lilith

A simple x86 kernel written in Crystal.

## Building

```
make build/kernel
```

## Features

* [x] Basic x86 support with paging/interrupts
* [x] Hybrid conservative-precise incremental garbage collector
* [x] IDE/ATA support (well, it can only read from primary master)
* [x] FAT16 support
* [x] Basic syscalls (open, read, write, spawn,...)
* [x] Preemptive multitasking!
* [x] Userpsace C library written in Crystal/C based on [PDCLib](https://github.com/DevSolar/pdclib/)
* [ ] And much more as I go...

## Credits

* [PDCLib](https://github.com/DevSolar/pdclib/)
* [dlmalloc](http://gee.cs.oswego.edu/dl/html/malloc.html)

## License

This program is licensed under GPLv3.

You should have received a copy of the GNU General Public License
along with this program.  If not, see https://www.gnu.org/licenses/.
