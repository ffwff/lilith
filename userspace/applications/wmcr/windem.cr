require "./wm/*"

client = Wm::Client.new.not_nil!
client << Wm::IPC.test_message
