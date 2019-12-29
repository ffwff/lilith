MODEL_NAME = "Model name: "
MEM_TOTAL = "MemTotal: "
MEM_USED = "MemUsed: "

def main
  model_name = ""
  mem_used = ""
  mem_total = ""
  File.open("/proc/kernel/cpuinfo") do |file|
    file.gets_to_end.split('\n') do |str|
      if str.starts_with?(MODEL_NAME)
        model_name = str[MODEL_NAME.size, -1]
      end
    end
  end
  File.open("/proc/kernel/meminfo") do |file|
    file.gets_to_end.split('\n') do |str|
      if str.starts_with?(MEM_USED)
        mem_used = str[MEM_USED.size, -1]
      elsif str.starts_with?(MEM_TOTAL)
        mem_total = str[MEM_TOTAL.size, -1]
      end
    end
  end
  print "OS: Lilith\n"
  print "CPU: ", model_name, "\n"
  print "Memory: ", mem_used, " / ", mem_total, "\n"
end

main
