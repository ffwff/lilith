<p align="center">
<img alt="Redox" width="346" src="https://github.com/DefunctLizard/lilith/blob/master/img/lilith-logo.png.png?raw=true">
A POSIX-like x86-64 kernel and userspace written in Crystal.</p>

## Screenshot

![screenshot](https://raw.githubusercontent.com/ffwff/lilith/master/img/05012020.png "screenshot of lilith")

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
