private abstract struct BoxedPointer
end

struct Box(T) < BoxedPointer

    def initialize
        @pointer = Pointer(T).null
        {% begin %}
        Serial.puts "{{ T.symbolize }}\n"
        {% end %}
        {% for ivar in T.instance_vars %}
            {% if ivar.type.ancestors[0] == BoxedPointer %}
                Serial.puts "{{ ivar.type.type_vars[0].symbolize }} "
                Serial.puts offsetof(T, @{{ ivar }})
                Serial.puts "\n"
            {% end %}
        {% end %}
    end

end