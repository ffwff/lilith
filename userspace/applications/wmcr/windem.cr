require "./wm/*"

client = Wm::Client.new.not_nil!
if (window = client.create_window)
  Wm::Painter.blit_rect(window.bitmap,
                        window.width, window.height,
                        window.width, window.height,
                        0, 0, 0x00ff0000)
end
