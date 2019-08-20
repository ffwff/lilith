build() {
    [[ ! -d "$build_dir/mruby" ]] && git clone https://github.com/mruby/mruby $build_dir/mruby
    pushd .
        cd $build_dir/mruby
        try_patch $script_dir/mruby.patch
        [[ $? -gt 1 ]] && exit 1
        ruby ./minirake -j`nproc` || exit 1
    popd
}

install() {
    sudo cp $build_dir/mruby/build/lilith/bin/mruby $install_dir/mruby
    sudo cp $build_dir/mruby/build/lilith/bin/mirb $install_dir/mirb
}