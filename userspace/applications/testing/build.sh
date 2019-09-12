build() {
	echo -ne
    ${opt_arch}-gcc -g -o $build_dir/testget $script_dir/testget.c -I$opt_toolsdir/include -L$opt_toolsdir/lib
}

install() {
    for i in $script_dir/*.c; do
        sudo cp $build_dir/$(basename $i .c) $install_dir/bin/
    done
    sudo cp $script_dir/*.lua $install_dir/
}