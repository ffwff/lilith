class Object
  {% for prefixes in { {"", "", "@", "#"}, {"class_", "self.", "@@", "."} } %}
    {%
      macro_prefix = prefixes[0].id
      method_prefix = prefixes[1].id
      var_prefix = prefixes[2].id
      doc_prefix = prefixes[3].id
    %}
    macro {{macro_prefix}}getter(*names)
      \{% for name in names %}
        \{% if name.is_a?(TypeDeclaration) %}
          def {{method_prefix}}\{{ name.var.id }} : \{{name.type}}
            {{var_prefix}}\{{ name.var.id }}
          end
        \{% else %}
          def {{method_prefix}}\{{ name.id }}
            {{var_prefix}}\{{ name.id }}
          end
        \{% end %}
      \{% end %}
    end

    macro {{macro_prefix}}getter!(*names)
      \{% for name in names %}
        \{% if name.is_a?(TypeDeclaration) %}
          def {{method_prefix}}\{{ name.var.id }} : \{{name.type}}
            {{var_prefix}}\{{ name.var.id }}.not_nil!
          end
        \{% else %}
          def {{method_prefix}}\{{ name.id }}
            {{var_prefix}}\{{ name.id }}.not_nil!
          end
        \{% end %}
      \{% end %}
    end

    macro {{macro_prefix}}setter(*names)
      \{% for name in names %}
        def {{method_prefix}}\{{ name.id }}=({{var_prefix}}\{{ name.id }})
        end
      \{% end %}
    end

    macro {{macro_prefix}}property(*names)
      \{% for name in names %}
        def {{method_prefix}}\{{ name.id }}
          {{var_prefix}}\{{ name.id }}
        end
        def {{method_prefix}}\{{ name.id }}=({{var_prefix}}\{{ name.id }})
        end
      \{% end %}
    end
  {% end %}

  def !=(other)
    !(self == other)
  end

  def not_nil!
    self
  end

  def unsafe_as(type : T.class) forall T
    x = self
    pointerof(x).as(T*).value
  end

  def as!(type : T.class) forall T
    if self.is_a?(T)
      self.unsafe_as type
    else
      abort "invalid type cast!"
    end
  end

  def ===(other)
    object_id == other.object_id
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
