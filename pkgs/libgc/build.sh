version=8.0.4

build() {
    if [[ ! -d "${build_dir}/gc-$version" ]]; then
        wget https://github.com/ivmai/bdwgc/releases/download/v$version/gc-$version.tar.gz
        tar xf $build_dir/gc-$version
    fi
    pushd .
        cd $build_dir/gc-$version
        try_patch $script_dir/bdwgc.patch
        [[ $? -gt 1 ]] && exit 1
        ./configure --prefix=$opt_toolsdir --target=$opt_arch --disable-mmap --enable-static || exit 1
        make -j`nproc` install
    popd
}

install() {
    echo -ne
}