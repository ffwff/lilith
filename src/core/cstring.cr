require "../alloc/gc.cr"

class CString < Gc

    getter size

    def initialize(buffer, @size : Int32)
        @buffer = GcPointer(UInt8).malloc(@size.to_u32)
        @size.times do |i|
            @buffer[i] = buffer[i]
        end
    end

    def initialize(@size : Int32)
        @buffer = GcPointer(UInt8).malloc(@size.to_u32)
        @size.times do |i|
            @buffer.ptr[i] = 0u8
        end
    end

    # methods
    def []=(k : Int, value : UInt8)
        panic "cstring: out of range" if k > size || k < 0
        @buffer.ptr[k] = value
    end

    def [](k : Int) : UInt8
        panic "cstring: out of range" if k > size || k < 0
        @buffer.ptr[k]
    end

    def ==(other : String)
        @size.times do |i|
            return false if @buffer.ptr[i] != other[i]
        end
        true
    end

    #
    def each(&block)
        @size.times do |i|
            yield @buffer.ptr[i]
        end
    end

    def to_s(io)
        each do |ch|
            io.puts ch.unsafe_chr
        end
    end

end