# lilith


A POSIX-like x86-64 kernel and userspace written in Crystal.

## Screenshot

![screenshot](https://raw.githubusercontent.com/ffwff/lilith/master/img/screenshot23.png "screenshot of lilith")

## Building

See [BUILDING.md](./BUILDING.md).

## Running

A CPU with x64 support is required to run the OS. The Makefile provides a script which will run QEMU on the kernel:

```
make run
```

To run with storage, an MBR-formatted hard drive image with a FAT16 partition must be provided in the running directory with the name `drive.img`. The kernel will automatically boot the `main.bin` executable on the hard drive, or panic if it can't be loaded.

Issue this command to run with gdb attached:

```
make rungdb_img
```

## Features

* Basic x86-64 support
* Hybrid conservative-precise incremental garbage collector
* IDE/ATA support (well, it can only load from primary master)
* FAT16 support
* Unix syscalls (open, read, write, spawn,...)
* Preemptive multitasking!
* Userspace C library written in Crystal (mostly)
* A window manager and some graphical programs (terminal emulator, file manager)
* And much more as I go...

## License

Lilith is licensed under MIT. See LICENSE for more details.
