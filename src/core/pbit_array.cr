struct PBitArray

    @size = 0
    def size; @size; end

    def initialize(@size)
        @pointer = Pointer(UInt8).pmalloc malloc_size
    end

    def self.null
        new 0, Pointer(UInt8).null
    end
    private def initialize(@size, @pointer)
    end

    # methods
    def []=(k : Int, value : Bool)
        panic "pbitarray: out of range" if k > size || k < 0
        if value
            @pointer[index_position k] |= 1.unsafe_shl(bit_position k)
        else
            @pointer[index_position k] &= ~1.unsafe_shl(bit_position k)
        end
    end

    def [](k : Int) : Bool
        panic "pbitarray: out of range" if k > size || k < 0
        if (@pointer[index_position k] & 1.unsafe_shl(bit_position k)) != 0
            true
        else
            false
        end
    end

    def first_set_index
        i = 0
        while i < malloc_size
            bsf = self.pointer[i].bsf
            if bsf != -1
                return Tuple.new(i, bsf + 1)
            end
        end
        Tuple.new(-1, 0)
    end

    # to_s
    def to_s(io)
        io.puts "PBitArray ["
        size.times do |i|
            io.puts (self[i] ? '1' : '0')
        end
        io.puts "]"
    end

    # size
    private def malloc_size : Int32
        (@size + 7).unsafe_div 8
    end

    # position
    private def index_position(k : Int)
        k.unsafe_div 8
    end
    private def bit_position(k : Int)
        k.unsafe_mod 8
    end

end