require "./wm/*"

client = Wm::Client.new.not_nil!
client << Wm::IPC.window_create_message(0,0,100,100)
