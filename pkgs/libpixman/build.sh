version=0.38.4

build() {
    if [[ ! -d "$build_dir/pixman-$version" ]]; then
        wget -O"$build_dir/pixman-$version.tar.xz" https://cairographics.org/releases/pixman-$version.tar.xz
        pushd .
            cd $build_dir/
            tar xf pixman-$version.tar.xz
            cd pixman-$version
            try_patch $script_dir/pixman.patch
        popd
    fi
    pushd .
        cd $build_dir/pixman-$version/pixman
        pixman_obj="pixman-access-accessors.o pixman-access.o pixman-bits-image.o pixman-combine-float.o pixman-combine32.o pixman-conical-gradient.o pixman-edge-accessors.o pixman-edge.o pixman-fast-path.o pixman-filter.o pixman-general.o pixman-glyph.o pixman-gradient-walker.o pixman-image.o pixman-implementation.o pixman-linear-gradient.o pixman-matrix.o pixman-noop.o pixman-radial-gradient.o pixman-region32.o pixman-solid-fill.o pixman-timer.o pixman-trap.o pixman-utils.o pixman-x86.o pixman-mmx.o pixman-sse2.o pixman-ssse3.o pixman.o"
        make CC=${opt_arch}-gcc CFLAGS="-include ../config.h -march=core2" $pixman_obj
        ${opt_arch}-ar rcs libpixman.a $pixman_obj
        cp libpixman.a $opt_toolsdir/lib
    popd
}

install() {
    echo -ne
}