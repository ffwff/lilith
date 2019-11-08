class Object
  def not_nil!
    self
  end

  macro getter(*names)
    {% for name in names %}
      {% if name.is_a?(TypeDeclaration) %}
        def {{ name.var.id }} : {{name.type}}
          @{{ name.var.id }}
        end
      {% else %}
        def {{ name.id }}
          @{{ name.id }}
        end
      {% end %}
    {% end %}
  end

  macro getter!(*names)
    {% for name in names %}
      {% if name.is_a?(TypeDeclaration) %}
        def {{ name.var.id }} : {{name.type}}
          @{{ name.var.id }}.not_nil!
        end
      {% else %}
        def {{ name.id }}
          @{{ name.id }}.not_nil!
        end
      {% end %}
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

  macro mod_property(*names)
    {% for name in names %}
    def {{ name.id }}
      @@{{ name.id }}
    end
    protected def {{ name.id }}=(@@{{ name.id }})
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
    panic "casting nil to not-nil!"
  end

  def to_s(io)
    io.print "nil"
  end

  def ==(other)
    false
  end

  def object_id
    0u64
  end
end
