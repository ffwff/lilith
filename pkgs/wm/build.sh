_download() {
    if [[ ! -f "$2" ]]; then
        wget -O"$2" "$1"
    fi
}

build() {
    _download https://raw.githubusercontent.com/dhepper/font8x8/master/font8x8_basic.h "$build_dir/font8x8_basic.h"

    ${opt_arch}-gcc -g -o $build_dir/wm $script_dir/wm.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lm -msse2
    # ${opt_arch}-gcc -g -o $build_dir/samplwin $script_dir/samplwin.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lm -msse2
    ${opt_arch}-gcc -g -o $build_dir/canvwin $script_dir/canvwin.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lm -msse2
    # ${opt_arch}-gcc -g -o $build_dir/cairowin $script_dir/cairowin.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -msse2 -lcairo -lpixman-1 -lm
}

install() {
    for i in $script_dir/*.c; do
        sudo cp $build_dir/$(basename $i .c) $install_dir/bin
    done
}