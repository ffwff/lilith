module DriverThread
  extend self
  
  @@locked = false
  
  def unlock
    @@locked = false
    # Serial.puts "driverthread: unlock\n"
  end

  def lock
    @@locked = true
    # Serial.puts "driverthread: lock \n"
  end
  
  def assert_unlocked
    if Multiprocessing.current_process.nil?
      return
    end
    unless Multiprocessing.current_process.not_nil!.kernel_process?
      return
    end
    # Serial.puts "assert_unlocked called from ", Multiprocessing.current_process.not_nil!.name, '\n'
    if @@locked
      name = Multiprocessing.current_process.not_nil!.name
      panic "kernel: subsystem must not be called from driver thread (called by ", name, ")\n"
    end
  end

end
