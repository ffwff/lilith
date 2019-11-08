version=1.6.37

build() {
    if [[ ! -d "$build_dir/libpng-$version" ]]; then
        wget -O"$build_dir/libpng-$version.tar.gz" https://downloads.sourceforge.net/libpng/libpng-$version.tar.xz
        pushd .
            cd $build_dir/
            tar xf libpng-$version.tar.gz
            cd libpng-$version
            try_patch $script_dir/libpng.patch
        popd
    fi
    pushd .
        cd $build_dir/libpng-$version
        CCFLAGS="-I$opt_toolsdir/include -DPNG_NO_CONSOLE_IO" \
        LDFLAGS="-L$opt_toolsdir/lib" \
            ./configure --host=$opt_arch --prefix="$opt_toolsdir" --enable-shared=no \
                --enable-arm-neon=no \
                --enable-mips-msa=no \
                --enable-powerpc-vsx=no && \
        make install -j`nproc` CPPFLAGS="-I$opt_toolsdir/include"
    popd
}

install() {
    echo -ne
}
