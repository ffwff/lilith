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
    y = nil
    z = A1.new(0xFFFFFFFF) # 5
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
    LibGc.cycle
    Serial.puts LibGc, "\n--\n"
end

class A3 < Gc
    def initialize(@x : (A1 | A3)); end
end

def test_gc2
    x = A1.new
    y = A3.new x
    z = A3.new x
    x = nil
    y = A1.new
end

def test_gc3
    x = A3.new(A3.new(A1.new))
    x = nil
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

def test_gc5
    while true
        x = A1.new 0xa.to_i64
    end
end

class GcTree < Gc

    @left : (GcTree | Nil) = nil
    @right : (GcTree | Nil) = nil
    def initialize(@depth : Int32); end
    def left=(x); @left = x; end
    def right=(x); @right = x; end

    def to_s(io)
        io.puts "("
        io.puts @depth
        io.puts " "
        io.puts @left
        io.puts " "
        io.puts @right
        io.puts " "
        io.puts ")"
    end

end

def mktree(i)
    if i == 0
        return nil
    end
    r = GcTree.new i
    r.left = mktree(i - 1)
    r.right = mktree(i - 1)
    r
end

def test_gc6
    tree= mktree(4).not_nil!
    Serial.puts tree, '\n'
    LibGc.cycle
    Serial.puts tree, '\n'
    LibGc.cycle
    tree.right = nil
    Serial.puts tree, '\n'
    LibGc.cycle
    Serial.puts LibGc, "\n---\n"
    LibGc.cycle
    Serial.puts LibGc, "\n---\n"
    LibGc.cycle
    Serial.puts tree, "\n", LibGc, "\n---\n"
    LibGc.cycle
    Serial.puts tree, "\n", LibGc, "\n---\n"
    LibGc.cycle
    Serial.puts tree, "\n", LibGc, "\n---\n"
    LibGc.cycle
    Serial.puts tree, "\n", LibGc, "\n---\n"
    tree.left = nil
    LibGc.cycle
    Serial.puts tree, "\n", LibGc, "\n---\n"
    LibGc.cycle
    Serial.puts tree, "\n", LibGc, "\n---\n"
    LibGc.cycle
    Serial.puts tree, "\n", LibGc, "\n---\n"
    LibGc.cycle
    Serial.puts tree, "\n", LibGc, "\n---\n"
end