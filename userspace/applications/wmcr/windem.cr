require "./wm/*"

client = Wm::Client.new.not_nil!
w, h = client.screen_resolution.not_nil!
STDERR.print w, ' ', h, '\n'
