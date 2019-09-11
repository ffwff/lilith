build() {
    ${opt_arch}-gcc -g -o $build_dir/testgc $script_dir/testgc.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lgc
}

install() {
    for i in $script_dir/*.c; do
        sudo cp $build_dir/$(basename $i .c) $install_dir/bin/
    done
}