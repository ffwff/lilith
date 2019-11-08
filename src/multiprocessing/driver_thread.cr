module Multiprocessing::DriverThread
  extend self

  @@locked = false

  def unlock
    @@locked = false
    # Serial.print "driverthread: unlock\n"
  end

  def lock
    @@locked = true
    # Serial.print "driverthread: lock \n"
  end

  def assert_unlocked
    if Multiprocessing::Scheduler.current_process.nil?
      return
    end
    unless Multiprocessing::Scheduler.current_process.not_nil!.kernel_process?
      return
    end
    # Serial.print "assert_unlocked called from ", Multiprocessing.current_process.not_nil!.name, '\n'
    if @@locked
      name = Multiprocessing::Scheduler.current_process.not_nil!.name
      panic "kernel: subsystem must not be called from driver thread (called by ", name, ")\n"
    end
  end
end
