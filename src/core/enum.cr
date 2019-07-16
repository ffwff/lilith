struct Enum

    def ==(other)
        value == other.value
    end

    def ===(other)
        value == other.value
    end

    def &(other : self)
        self.class.new(value & other.value)
    end

    def to_s(io)
        {% if @type.has_attribute?("Flags") %}
        {% else %}
        case value
        {% for member in @type.constants %}
        when {{@type}}::{{member}}.value
            io.puts {{member.stringify}}
        {% end %}
        else
            io.puts value
        end
        {% end %}
    end

end