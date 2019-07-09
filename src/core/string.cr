require "./int.cr"
require "./pointer.cr"

class String
    def size
        @length
    end

    def bytes
        pointerof(@c)
    end

    def each_char
        size.times do |i|
            yield bytes[i], i
        end
    end

    def to_s
        self
    end

    def to_s(io)
        each_char do |char|
            io.putc char
        end
    end

    @[AlwaysInline]
    def [](index : Int)
        bytes[index]
    end
end