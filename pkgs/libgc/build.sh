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
        ./configure --prefix=$opt_toolsdir --host=$opt_arch --enable-mmap=no --enable-static=yes --enable-shared=no
        make -j`nproc` install
    popd
}

install() {
    echo -ne
}