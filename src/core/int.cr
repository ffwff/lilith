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

    def ===(other)
        self == other
    end

    def abs
        self >= 0 ? self : self * -1
    end

    # bit manips
    @[AlwaysInline]
    def ffz : Int
        # find first zero bit, useful for bit arrays
        # NOTE: should check for zero first
        idx = 0
        asm("
            bsfl $1, $0
        " : "={eax}"(idx) : "{edx}"(~self.to_i32) :: "volatile")
        idx
    end

    @[AlwaysInline]
    def fls : Int
        # find last set bit in word
        # NOTE: should check for zero first
        idx = 0
        asm("
            bsrl $1, $0
        " : "={eax}"(idx) : "{edx}"(self.to_i32) :: "volatile")
        idx
    end

    @[AlwaysInline]
    def nearest_power_of_2
        n = self - 1
        while (n & (n - 1)) != 0
            n = n & (n - 1)
        end
        n.unsafe_shl 1
    end

    # format
    private BASE = "0123456789abcdefghijklmnopqrstuvwxyz"
    private def internal_to_s(base = 10)
        s = uninitialized UInt8[128]
        sign = self < 0
        n = self.abs
        i = 0
        while i < 128
            s[i] = BASE.bytes[n.unsafe_mod(base)]
            i += 1
            break if (n = n.unsafe_div(base)) == 0
        end
        if sign
            yield '-'.ord.to_u8
        end
        i -= 1
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

def min(a, b)
    a < b ? a : b
end

def max(a, b)
    a > b ? a : b
end