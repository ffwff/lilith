struct NullTerminatedSlice

    getter size

    def initialize(@buffer : UInt8*)
        @size = 0
        while @buffer[@size] != 0
            @size += 1
        end
    end

    def [](idx : Int)
        panic "NullTerminatedSlice: out of range" if idx > @size || idx < 0
        @buffer[@size]
    end

end