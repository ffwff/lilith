build() {
    pushd .
        cd $script_dir && \
        make install PREFIX=$opt_toolsdir
    popd
}

install() {
    echo -ne
}