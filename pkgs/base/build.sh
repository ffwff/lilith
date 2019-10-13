build() {
    echo -ne
}

install() {
    sudo mkdir -p $install_dir/bin/
    sudo rm -rf $install_dir/share
    sudo cp -r $script_dir/share $install_dir/share
}
