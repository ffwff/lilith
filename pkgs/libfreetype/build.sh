version=2.10.0

build() {
    if [[ ! -d "$build_dir/freetype-$version" ]]; then
        wget -O"$build_dir/freetype-$version.tar.gz" https://mirror.ossplanet.net/nongnu/freetype/freetype-$version.tar.gz
        pushd .
            cd $build_dir/
            tar xf freetype-$version.tar.gz
            try_patch $script_dir/freetype.patch
            cd freetype-$version
        popd
    fi
    pushd .
        cd $build_dir/freetype-$version
        CFLAGS="-I$opt_toolsdir/include -L$opt_toolsdir/lib -g -DFT_DEBUG_LEVEL_TRACE" \
            ./configure --prefix="$opt_toolsdir" --host=$opt_arch \
                --with-zlib=no --with-png=no --with-harfbuzz=no --with-bzip2=no
        make install -j`nproc`
    popd
}

install() {
    echo -ne
}
