ARGV = Array.new(ARGC_UNSAFE - 1) do |i|
  String.new(ARGV_UNSAFE[1 + i])
end

PROGRAM_NAME = String.new(ARGV_UNSAFE.value)
