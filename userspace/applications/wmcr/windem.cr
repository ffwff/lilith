require "./wm/*"

client = Wm::Client.new.not_nil!
client << Wm::IPC.window_create_message(420,420,420,420)
# client << Wm::IPC.test_message
