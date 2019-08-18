build() {
    git clone https://github.com/antirez/kilo $build_dir/kilo
    pushd .
        cd $build_dir/kilo
        try_patch $script_dir/kilo.patch
        [[ $? -gt 1 ]] && exit 1
        make -B CC=${opt_arch}-gcc || exit 1
    popd
}

install() {
    sudo cp $build_dir/kilo/kilo $install_dir/kilo
}