require "../drivers/io_driver.cr"
require "./static_array.cr"

struct Int

    def times
        x = 0
        while x < self
            yield x
            x += 1
        end
    end

    # math
    def abs
        self >= 0 ? self : self * -1
    end

    # format
    private def internal_to_s(base = 10)
        s = uninitialized UInt8[128]
        sign = self < 0
        n = self.abs
        i = 0
        while true
            s[i] = (n.unsafe_mod(base) + '0'.ord).to_u8
            i += 1
            break if (n = n.unsafe_div(base)) == 0
        end
        s[i] = '-'.ord.to_u8 if sign
        while true
            yield s[i]
            break if i == 0
            i -= 1
        end
    end

    def to_s(io, base = 10)
        internal_to_s(base) do |ch|
            io.putc ch
        end
    end

end