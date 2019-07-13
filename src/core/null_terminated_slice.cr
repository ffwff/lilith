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
        @buffer[idx]
    end
    def [](range : Range(Int32, Int32))
        panic "NullTerminatedSlice: out of range" if range.begin > range.end
        Slice(UInt8).new(@buffer + range.begin, range.size)
    end

    def each(&block)
        i = 0
        while i < @size
            yield @buffer[i]
            i += 1
        end
    end

end