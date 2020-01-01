# Build instructions

## For the kernel

### Crystal toolchain

You must get the dependencies for building Crystal listed on the [project's wiki](https://github.com/crystal-lang/crystal/wiki/All-required-libraries):

  * LLVM 9.0 (recommended, but any version later than 7.0 will probably do).
  * Latest pre-built version of Crystal ([v0.32.1](https://github.com/crystal-lang/crystal/releases/tag/0.32.1)). **You have to install it in `/usr/bin`**
  * libbsd
  * libedit
  * libevent
  * libgmp
  * libgc
  * libxml2
  * libyaml
  * pcre3
  * openssl

lilith needs to be compiled with a patched Crystal compiler, to build it, run the command:

```
make toolchain/crystal/.build/crystal
```

The Makefile will clone the [patched toolchain](https://github.com/ffwff/crystal/) into the `toolchain/crystal` directory and build it for you.

**NOTE:** If anything goes wrong, make sure to `cd toolchain/crystal && make clean && rm -rf ~/.cache/crystal` so that the patched Crystal is not littered with your past failed build artifacts.

### Cross-Binutils

You will also need an appropriate `x86_64-elf` Binutils toolchain in order to link and assemble the kernel, as well as `i686-elf` binutils to build the bootstrap code.

You can build the `i686-elf` and `x86_64-elf` toolchain by:

  * Downloading and compiling binutils in a build directory for the `x86_64-elf` target ([recommend build instructions by phill-opp](https://os.phil-opp.com/cross-compile-binutils/))
  * In another build directory, compile binutils for the `i686-elf` target.
  * Install it in somewhere convenient like in a `~/binutils` folder, make sure you set the `$PATH` variable too!

### Building the kernel!

Now that you have everything set up, it's time to build the kernel! In the parent project directory, run:

```
make build/kernel RELEASE=1
```

**NOTE:** Only release builds work right now (until [#12](https://github.com/ffwff/lilith/issues/12) is fixed)

## For the userspace

### Toolchain

A Makefile is provided for building the userspace toolchain, to build it, go to the `userspace/toolchain` directory and use `make`. The build system compiles the userspace toolchain for `x86_64-elf-lilith` by default.

Once built, a patched version of GCC/Binutils will be installed in `userspace/toolchain/tools/bin`, simply set your PATH variable to that location (or use the `source ./env.sh` script) and you can use the toolchain (with the `i386-elf-lilith` or `x86_64-elf-lilith` prefix).

### Building packages

Lilith currently only has FAT16 driver so the easiest way to debug it is with a hard drive image. Build the 50MB MBR-formatted `disk.img` file by doing:

```
make disk.img
```

(You must have `dd`, `losetup`, `mkfs.fat`, `grub-install` commands installed)

After building the toolchain, set the necessary environment variables by doing:

```
source ./env.sh
```

You'll have to build libc first before building any other packages:

```
./pkgs/missio build libc
```

You can now build packages by using the `missio` package manager.

