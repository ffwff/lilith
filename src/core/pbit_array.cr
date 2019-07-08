struct PBitArray

    @size = 0
    def size; @size; end

    def initialize(@size)
        @pointer = Pointer(UInt32).pmalloc malloc_size
    end

    def self.null
        new 0, Pointer(UInt32).null
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

    def first_unset
        i = 0
        while i < malloc_size
            if @pointer[i] != (~0).to_u32
                return i * 32 + @pointer[i].ffz
            end
            i += 1
        end
        -1
    end

    def first_unset_from(idx : Int32)
        i = idx
        while i < malloc_size
            if @pointer[i] != (~0).to_u32
                return Tuple.new(i, i * 32 + @pointer[i].ffz)
            end
            i += 1
        end
        Tuple.new(-1, -1)
    end

    # TODO: find a better algorithm
    def first_unset_bits(n : Int)
        panic "unsupported" if n > 8
        max_words = 1
        i = 0
        while i < malloc_size
            first_idx = i * 32 + @pointer[i].ffz
            next_idx = begin
                j = i
                while j < malloc_size
                    if @pointer[i] == 0
                        return 1
                    end
                    j += 1
                end
            end
            i += 1
        end
        -1
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
        (@size + 31).unsafe_div 32
    end

    # position
    private def index_position(k : Int)
        k.unsafe_div 32
    end
    private def bit_position(k : Int)
        k.unsafe_mod 32
    end

end