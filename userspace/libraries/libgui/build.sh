build() {
    pushd .
        cd $script_dir && \
        make install PREFIX=$opt_toolsdir \
        CC=$opt_arch-gcc CFLAGS="-I$opt_toolsdir/include -L$opt_toolsdir/lib"
    popd
}

install() {
    echo -ne
}
