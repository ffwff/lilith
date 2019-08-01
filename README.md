# lilith

A POSIX-like x86 kernel written in Crystal.

## Building

```
make build/kernel
```

**NOTE:** lilith needs to be compiled with a patched crystal compiler, to build it, run the command:

```
make toolchain/crystal/.build/crystal
```

You will also need an appropriate `i686-elf` gcc/binutils toolchain in order to link and assemble the kernel.

### Building the userspace

A Makefile is provided for building the userspace toolchain, to build it, go to the `userspace/toolchain` directory and use `make`.

Once built, a patched version of GCC/Binutils will be installed in `userspace/toolchain/tools/bin`, simply set your PATH variable to that location and you can use the toolchain (with the `i386-elf-lilith` prefix)

## Running

A Pentium 4 compatible PC is required to run the OS. The Makefile provides a script which will run QEMU on the kernel:

```
make run
```

To run with storage, an MBR-formatted hard drive image with a FAT16 partition must be provided in the running directory with the name `drive.img`. The kernel will automatically boot the `main.bin` executable on the hard drive, or panic if it can't be loaded.

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

## License

This program is licensed under GPLv3.

You should have received a copy of the GNU General Public License
along with this program.  If not, see https://www.gnu.org/licenses/.
