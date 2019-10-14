class Object
  def not_nil!
    self
  end

  macro getter(*names)
    {% for name in names %}
    def {{ name.id }}
      @{{ name.id }}
    end
    {% end %}
  end

  macro setter(*names)
    {% for name in names %}
    def {{ name.id }}=(@{{ name.id }})
    end
    {% end %}
  end

  macro property(*names)
    {% for name in names %}
    def {{ name.id }}
      @{{ name.id }}
    end
    def {{ name.id }}=(@{{ name.id }})
    end
    {% end %}
  end

  def unsafe_as(type : T.class) forall T
    x = self
    pointerof(x).as(T*).value
  end
end

struct Nil
  def not_nil!
    abort "casting nil to not-nil!"
  end

  def to_s(io)
    io << "nil"
  end

  def ==(other)
    false
  end

  def object_id
    0u64
  end
end
