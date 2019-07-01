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
end