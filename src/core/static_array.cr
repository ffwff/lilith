struct StaticArray(T, N)
    macro [](*args)
        %array = uninitialized StaticArray(typeof({{*args}}), {{args.size}})
        {% for arg, i in args %}
        %array.to_unsafe[{{i}}] = {{arg}}
        {% end %}
        %array
    end

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

    def size
        N
    end

    def each : Nil
        {% for i in 0...N %}
            yield self[{{i}}]
        {% end %}
    end

end