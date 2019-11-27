fun __assert__(truthy : LibC::Int, s : LibC::UString)
  LibC.fprintf LibC.stderr, "assertion failed: %s\n", s
  abort
end
