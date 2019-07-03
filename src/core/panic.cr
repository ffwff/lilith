require "../drivers/serial.cr"

def panic(s)
    # TODO
    Serial.puts s
    while true
    end
end

def raise(*args)
end