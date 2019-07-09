class Reference

    def ==(other : self)
        same?(other)
    end

    def ==(other)
        false
    end

    def same?(other : Reference)
        object_id == other.object_id
    end

end
