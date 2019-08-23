_download() {
    if [[ ! -f "$2" ]]; then
        wget -O"$2" "$1"
    fi
}

build() {
    _download https://raw.githubusercontent.com/nothings/stb/master/stb_image.h "$build_dir/stb_image.h"

    for i in $script_dir/*.c; do
        ${opt_arch}-gcc -O2 -o $build_dir/$(basename $i .c) $i -lm
    done
}

install() {
    for i in $script_dir/*.c; do
        sudo cp $build_dir/$(basename $i .c) $install_dir/bin
    done
    sudo cp $build_dir/test.png $install_dir/test.png
}