struct StaticArray(T, N)

    def to_unsafe : Pointer(T)
        pointerof(@buffer)
    end

    @[AlwaysInline]
    def []=(index : Int, value : T)
        to_unsafe[index] = value
    end

end