class BTreeNode(K, V)

    def initialize(@key : K, @value : V, @left = nil, @right = nil)
    end

    def insert(key, value)
        if key == @key
            @value = value
        elsif key < @key
            if @left.nil?
                @left = BTreeNode(K, V).new key, value
            else
                @left.not_nil!.insert key, value
            end
        elsif key > @key
            if @right.nil?
                @right = BTreeNode(K, V).new key, value
            else
                @right.not_nil!.insert key, value
            end
        end
    end

    def search(key)
        if key == @key
            @value
        elsif key < @key
            if @left.nil?
                nil
            else
                @left.not_nil!.search key
            end
        else
            if @right.nil?
                nil
            else
                @right.not_nil!.search key
            end
        end
    end

    def to_s(io)
        io.puts "[", @key, ": ", @value, "]"
        io.puts "( "
        @left.to_s io
        io.puts " "
        @right.to_s io
        io.puts " )"
    end

end

class BTree(K, V)

    def initialize(@root = nil)
    end

    def insert(key, value)
        if @root.nil?
            @root = BTreeNode(K, V).new key, value
        else
            @root.not_nil!.insert key, value
        end
    end

    def search(key)
        if @root.nil?
            nil
        else
            @root.not_nil!.search key
        end
    end

    def to_s(io)
        if @root.nil?
            io.puts "()"
        else
            io.puts @root
        end
    end

end