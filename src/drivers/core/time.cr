module Time
  extend self

  @@stamp = 0u64
  class_property stamp

  @@usecs_since_boot = 0u64
  class_property usecs_since_boot
end
