build() {
  pushd .
    cd $script_dir
    for i in ./*.cr; do
        ./compile $i $build_dir/$(basename $i .cr)
    done
  popd
}

install() {
    for i in $script_dir/*.cr; do
        sudo cp $build_dir/$(basename $i .cr) $install_dir/bin
    done
}
