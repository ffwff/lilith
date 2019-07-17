module IoProcess
    extend self

    def tick
        while true
            Serial.puts "io!\n"
        end
    end

end