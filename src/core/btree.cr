class BTreeNode(K, V)

    def initialize(@key : K, @value : V, @left : BTreeNode(K, V) | Nil = nil, @right : BTreeNode(K, V) | Nil = nil)
    end

    property key, value, left, right

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

    def initialize(@root : BTreeNode(K, V) | Nil = nil)
    end
    property root

    def search(key)
        if @root.nil?
            nil
        else
            @root.not_nil!.search key
        end
    end

    def balance(nelems)
        # turn into sorted linked list
        tail = root.not_nil!
        rest = tail.right
        while !rest.nil?
            rest = rest.not_nil!
            if rest.left.nil?
                tail = rest
                rest = rest.right
            else
                temp = rest.left.not_nil!
                rest.left = temp.right
                temp.right = rest
                rest = temp
                tail.right = temp
            end
        end

        # balance it
        root = @root.not_nil!
        leaves = nelems + 1 - nelems.lowest_power_of_2
        compress root, leaves
        nelems -= leaves
        while nelems > 1
            nelems = nelems.unsafe_div(2)
            compress root, nelems
        end
    end

    private def compress(root, count)
        scanner = root.not_nil!
        i = 0
        while i < count
            child = scanner.right.not_nil!
            scanner.right = child.right
            scanner = scanner.right.not_nil!
            child.right = scanner.left
            scanner.left = child
            i += 1
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