struct StaticArray(T, N)

    def to_unsafe : Pointer(T)
        pointerof(@buffer)
    end

    @[AlwaysInline]
    def []=(index : Int, value : T)
        panic "setting out of bounds!" if index > N
        to_unsafe[index] = value
    end

    @[AlwaysInline]
    def [](index : Int) T
        panic "accessing out of bounds!" if index > N
        to_unsafe[index]
    end

end