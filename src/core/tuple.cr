struct Tuple

    def each : Nil
        {% for i in 0...T.size %}
            yield self[{{i}}]
        {% end %}
    end

end