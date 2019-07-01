require "../drivers/serial.cr"

def panic(s)
    # TODO
    Serial.puts s
    while true
        asm("nop")
    end
end