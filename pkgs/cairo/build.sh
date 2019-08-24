version=1.16.0

build() {
    wget -O"$build_dir/cairo-$version.tar.xz" https://cairographics.org/releases/cairo-$version.tar.xz
    pushd .
        cd $build_dir/
        tar xf cairo-$version.tar.xz
        cd cairo-$version
        [[ $? -gt 1 ]] && exit 1
        make -B CC=${opt_arch}-gcc || exit 1
    popd
}

install() {
    echo -ne
}