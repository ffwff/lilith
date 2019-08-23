build() {
    echo -ne
}

install() {
    sudo mkdir -p $install_dir/bin/
    sudo cp -r $script_dir/share $install_dir/share
}