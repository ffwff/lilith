lib LibC
  fun read(fd : LibC::Int, str : LibC::String, len : LibC::Int) : LibC::Int
  fun write(fd : LibC::Int, str : LibC::String, len : LibC::Int) : LibC::Int
  fun abort : NoReturn
end
