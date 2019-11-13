build() {
  LDFLAGS="-I$opt_toolsdir/include -L$opt_toolsdir/lib -lpng -lz -lm -msse2" $script_dir/compile $script_dir/wmcr.cr $build_dir/wmcr
  $script_dir/compile $script_dir/windem.cr $build_dir/windem
  $script_dir/compile $script_dir/cterm.cr $build_dir/cterm
}

install() {
  for i in $script_dir/*.cr; do
    sudo cp $build_dir/$(basename $i .cr) $install_dir/bin
  done
}
