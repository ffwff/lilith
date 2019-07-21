lib LibC

    alias Mutex = Void*

    enum ThreadResult : UInt32
        Success  = 0
        Busy     = 1
        Error    = 2
        ENOMEM   = 3
        TimedOut = 4
    end

end

fun mutex_lock(mutex : LibC::Mutex) : LibC::ThreadResult
    LibC::ThreadResult::Success
end

fun mutex_unlock(mutex : LibC::Mutex) : LibC::ThreadResult
    LibC::ThreadResult::Success
end