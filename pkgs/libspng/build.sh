_download() {
    if [[ ! -f "$2" ]]; then
        wget -O"$2" "$1"
    fi
}

build() {
    _download https://raw.githubusercontent.com/randy408/libspng/master/spng.c "$build_dir/spng.c"
    _download https://raw.githubusercontent.com/randy408/libspng/master/spng.h "$build_dir/spng.h"
    $opt_arch-gcc -c -g -o $build_dir/spng.o $build_dir/spng.c -I$opt_toolsdir/include -DSPNG_NO_TARGET_CLONES
    $opt_arch-ar rcs $opt_toolsdir/lib/libspng.a $build_dir/spng.o
    cp $build_dir/spng.h $opt_toolsdir/include/spng.h
}

install() {
	echo -ne
}
