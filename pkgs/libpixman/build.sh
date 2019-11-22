version=0.38.4

build() {
    if [[ ! -d "$build_dir/pixman-$version" ]]; then
        wget -O"$build_dir/pixman-$version.tar.gz" https://cairographics.org/releases/pixman-$version.tar.gz
        pushd .
            cd $build_dir/
            tar xf pixman-$version.tar.gz
            cd pixman-$version
            try_patch $script_dir/pixman.patch
        popd
    fi
    pushd .
        cd $build_dir/pixman-$version
        ./configure --host=$opt_arch --prefix="$opt_toolsdir" --enable-shared=no --enable-intel-sse=yes
        make install -j`nproc`
    popd
}

install() {
    echo -ne
}
