lib LibC
  fun waitfd(fds : LibC::Int*, nfd : LibC::SizeT, timeout : LibC::UInt) : LibC::Int
end

class IO::Select

  @targets = Array(IO::FileDescriptor).new
  @fds = Array(Int32).new

  def <<(target)
    @targets.push target
    @fds.push target.fd
  end

  def wait(timeout = 0u32)
    if (fd = LibC.waitfd(@fds.to_unsafe,
                         @fds.size,
                         timeout)) >= 0
      @targets.each do |target|
        return target if target.fd == fd
      end
    end
  end

  def self.wait(io : IO::FileDescriptor, timeout = 0u32)
    fd : LibC::Int = io.fd
    LibC.waitfd(pointerof(fd), 1, timeout)
  end

end
