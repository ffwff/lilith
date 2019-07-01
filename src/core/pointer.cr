struct Pointer(T)
    def self.null
        new(0u64)
    end

    def [](offset : Int)
        (self + offset.to_i64).value
    end

    def []=(offset : Int, data : T)
        (self + offset.to_i64).value = data
    end
end