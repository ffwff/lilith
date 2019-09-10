build() {
    pushd .
        cd $script_dir && \
        make -B -j`nproc` RELEASE=1 && \
        make install \
            LIBDIR=$opt_toolsdir/lib/gcc/$opt_arch/8.3.0/ \
            INCLUDEDIR=$opt_toolsdir/lib/gcc/$opt_arch/8.3.0/include
    popd
}

install() {
    echo -ne
}