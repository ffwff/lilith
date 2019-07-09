require "../drivers/serial.cr"

def panic(*args)
    # TODO
    Serial.puts *args
    while true
    end
end

def raise(*args)
end