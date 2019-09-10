_download() {
    if [[ ! -f "$2" ]]; then
        wget -O"$2" "$1"
    fi
}

build() {
    _download https://raw.githubusercontent.com/nothings/stb/master/stb_image.h "$build_dir/stb_image.h"
    _download https://raw.githubusercontent.com/dhepper/font8x8/master/font8x8_basic.h "$build_dir/font8x8_basic.h"
    _download https://upload.wikimedia.org/wikipedia/en/7/7d/Lenna_%28test_image%29.png "$build_dir/test.png"

    ${opt_arch}-gcc -O2 -o $build_dir/catimg $script_dir/catimg.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lm
    ${opt_arch}-gcc -O2 -o $build_dir/canvdem $script_dir/canvdem.c -I$opt_toolsdir/include
    # ${opt_arch}-gcc -g -o $build_dir/cairodem $script_dir/cairodem.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lcairo -lpixman-1 -lm
}

install() {
    for i in $script_dir/*.c; do
        sudo cp $build_dir/$(basename $i .c) $install_dir/bin
    done
    sudo cp $build_dir/test.png $install_dir/test.png
}