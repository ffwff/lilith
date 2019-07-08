class A1 < Gc
    def initialize(@dbg = 0xdeadbeef)
    end
    def dbg; @dbg; end
end

class A2 < Gc
    def initialize
        @dbg1 = A1.new 0xa0baa0ba
        @dbg2 = A1.new 0xabababab
    end
end

def test_gc1
    x = A1.new # 1
    Serial.puts "x: ",x.crystal_type_id, "\n"
    y = A2.new # 2, 3, 4?
    Serial.puts "y: ", pointerof(y), " ",y.crystal_type_id, "\n"
    z = A1.new(0xFFFFFFFF) # 5

    Serial.puts LibGc, "\n---\n"
    LibGc.cycle
    Serial.puts LibGc, "\n---\n"
    LibGc.cycle
    Serial.puts LibGc, "\n---\n"
    x = 0
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
    Serial.puts "y: ", pointerof(y), " ",y.crystal_type_id, "\n"
    LibGc.cycle
    Serial.puts LibGc, "\n"

    LibGc.cycle
    Serial.puts LibGc, "\n"
end

class A3 < Gc
    def initialize(@x : (A1 | A3)); end
end

def test_gc2
    x = A1.new
    y = A3.new x
    z = A3.new x
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
    x = 0
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
end

def test_gc3
    x = A3.new(A3.new(A1.new))
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
    x = 0
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
end

def test_gc4
    100.times do |i|
        x = A1.new 0xa.to_i64
        y = A1.new 0xb.to_i64
        z = A1.new 0xc.to_i64
        a = A1.new 0xd.to_i64
        LibGc.cycle
        Serial.puts LibGc, "\n--\n"
        panic "failed" if x.dbg != 0xa
        panic "failed" if y.dbg != 0xb
        panic "failed" if z.dbg != 0xc
        panic "failed" if a.dbg != 0xd
    end
end