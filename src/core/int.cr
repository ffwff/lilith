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
    def ~
        self ^ -1
    end

    def abs
        self >= 0 ? self : self * -1
    end

    def bsf : Int
        # get least significant set bit
        # useful for bit arrays
        return -1 if self == 0
        idx = 0
        asm("
            bsf $1, $0
        " : "={eax}"(idx) : "{edx}"(self) :: "volatile")
        idx
    end

    # format
    private BASE = "0123456789abcdefghijklmnopqrstuvwxyz"
    private def internal_to_s(base = 10)
        s = uninitialized UInt8[128]
        sign = self < 0
        n = self.abs
        i = 0
        while true
            s[i] = BASE.bytes[n.unsafe_mod(base)]
            i += 1
            break if (n = n.unsafe_div(base)) == 0
        end
        if sign
            yield '-'.ord.to_u8
        else
            i -= 1
        end
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