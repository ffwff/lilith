struct Tuple

    def self.new(*args : *T)
        args
    end

    def each : Nil
        {% for i in 0...T.size %}
            yield self[{{i}}]
        {% end %}
    end

    def to_s(io)
        io.puts "Tuple("
        each do |x|
            io.puts x, ","
        end
        io.puts ")"
    end

end