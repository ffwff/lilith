lib LibC
  alias Mutex = Void*

  enum ThreadResult : UInt32
    Success  = 0
    Busy     = 1
    Error    = 2
    ENOMEM   = 3
    TimedOut = 4
  end

  @[Flags]
  enum MutexType : Int32
    Plain     = 0
    Recursive = 1
    Timed     = 2
  end
end

fun mtx_init(mutex : LibC::Mutex, type : LibC::MutexType) : LibC::ThreadResult
  LibC::ThreadResult::Success
end

fun mtx_destroy(mutex : LibC::Mutex)
end

fun mtx_lock(mutex : LibC::Mutex) : LibC::ThreadResult
  LibC::ThreadResult::Success
end

fun mtx_unlock(mutex : LibC::Mutex) : LibC::ThreadResult
  LibC::ThreadResult::Success
end
