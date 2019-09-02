build() {
    for i in $script_dir/*.c; do
        ${opt_arch}-gcc -g -o $build_dir/$(basename $i .c) $i
    done
}

install() {
    for i in $script_dir/*.c; do
        sudo cp $build_dir/$(basename $i .c) $install_dir/bin
    done
}