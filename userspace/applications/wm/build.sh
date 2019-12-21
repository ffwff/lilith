build() {
  #LDFLAGS="-I$opt_toolsdir/include -L$opt_toolsdir/lib $script_dir/painter/c/alpha_blend.c -lpng -lz -lm -msse2" $script_dir/compile $script_dir/wm.cr $build_dir/wm
  #$script_dir/compile $script_dir/windem.cr $build_dir/windem
  #$script_dir/compile $script_dir/desktop.cr $build_dir/desktop
  LDFLAGS="-I$opt_toolsdir/include -L$opt_toolsdir/lib -lpng -lz -lm -msse2" $script_dir/compile $script_dir/cterm.cr $build_dir/cterm
  #$script_dir/compile $script_dir/cbar.cr $build_dir/cbar
  #LDFLAGS="-I$opt_toolsdir/include -L$opt_toolsdir/lib -lpng -lz -lm -msse2" $script_dir/compile $script_dir/cfm.cr $build_dir/cfm
  #LDFLAGS="-I$opt_toolsdir/include -L$opt_toolsdir/lib -lpng -lz -lm -msse2" $script_dir/compile $script_dir/pape.cr $build_dir/pape
}

install() {
  for i in $script_dir/*.cr; do
    sudo cp $build_dir/$(basename $i .cr) $install_dir/bin
  done
}
