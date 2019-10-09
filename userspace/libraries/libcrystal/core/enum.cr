struct Enum
  def ==(other)
    value == other.value
  end

  def !=(other)
    value != other.value
  end

  def ===(other)
    value == other.value
  end

  def |(other : self)
    self.class.new(value | other.value)
  end

  def &(other : self)
    self.class.new(value & other.value)
  end

  def ~
    self.class.new(~value)
  end

  def includes?(other : self)
    (value & other.value) != 0
  end

  def to_s(io)
    {% if @type.has_attribute?("Flags") %}
      if value == 0
        io.puts "None"
      else
        found = false
        {% for member in @type.constants %}
          {% if member.stringify != "All" %}
            if {{@type}}::{{member}}.value != 0 && (value & {{@type}}::{{member}}.value) != 0
              io.puts " | " if found
              io.puts {{member.stringify}}
              found = true
            end
          {% end %}
        {% end %}
        io.puts value unless found
      end
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
