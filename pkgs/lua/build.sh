version=5.3.5

build() {
    if [[ ! -d "$build_dir/lua-$version" ]]; then
        wget -O"$build_dir/lua-$version.tar.gz" https://www.lua.org/ftp/lua-$version.tar.gz
        pushd .
            cd $build_dir/
            tar xf lua-$version.tar.gz
            cd lua-$version
        popd
    fi
    pushd .
        cd $build_dir/lua-$version/src
        make -j`nproc` generic CC="$opt_arch-gcc -g" LD=$opt_arch-ld
    popd
}

install() {
    sudo cp $build_dir/lua-$version/src/{lua,luac} $install_dir/bin/
}