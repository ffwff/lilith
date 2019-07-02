struct Proc

    def pointer
        internal_representation[0]
    end

    def closure_data
        internal_representation[1]
    end

    def closure?
        !closure_data.null?
    end

    private def internal_representation
        func = self
        ptr = pointerof(func).as({Void*, Void*}*)
        ptr.value
    end

end