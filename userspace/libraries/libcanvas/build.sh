build() {
    pushd .
        cd $build_dir
        if [[ ! -d "libcanvas" ]]; then
            git clone https://github.com/ffwff/libcanvas
        fi
        cd libcanvas
        make install PREFIX=$opt_toolsdir
    popd
}

install() {
    echo -ne
}