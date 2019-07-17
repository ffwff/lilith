module IoProcess
    extend self

    def loop
        while true
            Serial.puts "io!\n"
        end
    end

end

fun kio_process
    asm("mov $$0x7ffff000, %esp")
    IoProcess.loop
end