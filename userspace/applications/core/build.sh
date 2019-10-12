build() {
    for i in $script_dir/*.cr; do
        $script_dir/compile $i $build_dir/$(basename $i .cr)
    done
}

install() {
    for i in $script_dir/*.cr; do
        sudo cp $build_dir/$(basename $i .cr) $install_dir/bin
    done
}
