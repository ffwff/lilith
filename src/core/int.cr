struct Int

    def times
        x = 0
        while x < self
            yield x
            x += 1
        end
    end

end