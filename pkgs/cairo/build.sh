version=1.16.0

build() {
    if [[ ! -d "$build_dir/cairo-$version" ]]; then
        wget -O"$build_dir/cairo-$version.tar.xz" https://cairographics.org/releases/cairo-$version.tar.xz
        pushd .
            cd $build_dir/
            tar xf cairo-$version.tar.xz
            cd cairo-$version
            echo `pwd`
            try_patch $script_dir/cairo.patch
        popd
    fi
    pushd .
        cd $build_dir/cairo-$version
        ./configure \
            --prefix="$opt_toolsdir" \
            --host=i386-elf-lilith \
            --enable-ps=no --enable-pdf=no --enable-svg=no \
            --enable-script=no --enable-interpreter=no \
            --enable-xlib=no --enable-xcb=no \
            --enable-ft=no --enable-fc=no \
            --enable-gobject=no
        make -j12
    popd
}

install() {
    pushd .
        cd $build_dir/cairo-$version
        make install
    popd
}