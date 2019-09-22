_download() {
    if [[ ! -f "$2" ]]; then
        wget -O"$2" "$1"
    fi
}

build() {
    _download https://raw.githubusercontent.com/dhepper/font8x8/master/font8x8_basic.h "$build_dir/font8x8_basic.h"

    ${opt_arch}-gcc -g -o $build_dir/wm $script_dir/wm.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lm -msse2
    ${opt_arch}-gcc -g -o $build_dir/desktop $script_dir/desktop.c -I$opt_toolsdir/include -L$opt_toolsdir/lib
    ${opt_arch}-gcc -g -o $build_dir/cterm $script_dir/cterm.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lm -lgui -lcanvas -lwmc -msse2
    ${opt_arch}-gcc -g -o $build_dir/cbar $script_dir/cbar.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lm -lgui -lcanvas -lwmc -msse2
    ${opt_arch}-gcc -g -o $build_dir/fm $script_dir/fm.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lgui -lcanvas -lwmc -lm  -msse2
    ${opt_arch}-gcc -g -o $build_dir/pape $script_dir/pape.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lgui -lcanvas -lwmc -lpng -lz -lm  -msse2
}

install() {
    for i in $script_dir/*.c; do
        sudo cp $build_dir/$(basename $i .c) $install_dir/bin
    done
}
