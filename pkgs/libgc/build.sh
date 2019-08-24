build() {
    if [[ ! -d "${build_dir}/gc-8.0.4" ]]; then
        wget https://github.com/ivmai/bdwgc/releases/download/v8.0.4/gc-8.0.4.tar.gz
        tar xf $build_dir/kilo
    fi
    pushd .
        cd $build_dir/gc-8.0.4
        try_patch $script_dir/bdwgc.patch
        [[ $? -gt 1 ]] && exit 1
        ../configure --target=$opt_arch --disable-mmap --enable-static || exit 1
        make -j`nproc` || exit 1
    popd
}