struct StaticArray(T, N)

    def to_unsafe : Pointer(T)
        pointerof(@buffer)
    end

end