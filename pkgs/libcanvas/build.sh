build() {
    pushd .
        cd $script_dir/src && \
        make install PREFIX=$opt_toolsdir
    popd
}

install() {
    echo -ne
}