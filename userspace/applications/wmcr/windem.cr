require "./wm/*"

client = Wm::Client.new.not_nil!
client.create_window
