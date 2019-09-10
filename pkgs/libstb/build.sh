_download() {
    if [[ ! -f "$2" ]]; then
        wget -O"$2" "$1"
    fi
}

build() {
    _download https://raw.githubusercontent.com/nothings/stb/master/stb_image.h "$build_dir/stb_image.h"
    _download https://raw.githubusercontent.com/dhepper/font8x8/master/font8x8_basic.h "$build_dir/font8x8_basic.h"
    mkdir -p $opt_toolsdir/include/stb
    cp $build_dir/stb_image.h $opt_toolsdir/include/stb/stb_image.h
    cp $build_dir/font8x8_basic.h $opt_toolsdir/include/font8x8_basic.h
}

install() {
	echo -ne
}