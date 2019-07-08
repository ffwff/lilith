class BTreeNode(K, V)

    def initialize(@key, @value, @left = Nil, @right = Nil)
    end

    def insert(key, value)
        if key == @key
            @value = value
        elsif key < @key
            if @left.nil?
                @left = BTreeNode.new key, value
            else
                insert(@left, key, value)
            end
        elsif key > @key
            if @right.nil?
                @right = BTreeNode.new key, value
            else
                insert(@right, key, value)
            end
        end
    end

end