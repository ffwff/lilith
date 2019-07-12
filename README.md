# crystal-os

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
* [ ] Basic syscalls
* [x] Preemptive multitasking!
* [ ] And much more as I go...

## License

This program is licensed under GPLv3.

You should have received a copy of the GNU General Public License
along with this program.  If not, see https://www.gnu.org/licenses/.