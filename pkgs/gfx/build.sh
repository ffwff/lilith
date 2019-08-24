_download() {
    if [[ ! -f "$2" ]]; then
        wget -O"$2" "$1"
    fi
}

build() {
    _download https://raw.githubusercontent.com/nothings/stb/master/stb_image.h "$build_dir/stb_image.h"

    ${opt_arch}-gcc -O2 -o $build_dir/catimg $script_dir/catimg.c -lm
    ${opt_arch}-gcc -O2 -o $build_dir/cairo-demo $script_dir/cairo-demo.c -I$opt_toolsdir/include -L$opt_toolsdir/lib -lcairo -lpixman -lm
}

install() {
    for i in $script_dir/*.c; do
        sudo cp $build_dir/$(basename $i .c) $install_dir/bin
    done
    sudo cp $build_dir/test.png $install_dir/test.png
}