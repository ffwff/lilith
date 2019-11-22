version=1.2.11

build() {
    if [[ ! -d "$build_dir/zlib-$version" ]]; then
        wget -O"$build_dir/zlib-$version.tar.gz" https://www.zlib.net/zlib-$version.tar.gz
        pushd .
            cd $build_dir/
            tar xf zlib-$version.tar.gz
            cd zlib-$version
        popd
    fi
    pushd .
        cd $build_dir/zlib-$version
        CC=${opt_arch}-gcc ./configure --prefix="$opt_toolsdir" --static
        make install -j`nproc`
    popd
}

install() {
    echo -ne
}
