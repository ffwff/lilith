build() {
    for i in $script_dir/*.c; do
        ${opt_arch}-gcc -O2 -o $build_dir/$(basename $i .c) $i
    done
}

install() {
    for i in $script_dir/*.c; do
        sudo cp $build_dir/$(basename $i .c) $install_dir
    done
}