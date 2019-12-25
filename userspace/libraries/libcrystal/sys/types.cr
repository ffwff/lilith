struct Int
  def to_int
    self.to_i32
  end

  def to_uint
    self.to_u32
  end

  {% if flag?(:bits32) %}
    def to_usize
      self.to_u32
    end
  {% else %}
    def to_usize
      self.to_u64
    end
  {% end %}
end
