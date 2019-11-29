fun __assert__(truthy : LibC::Int, s : UInt8*)
  LibC.fprintf LibC.stderr, "assertion failed: %s\n", s
  abort
end
