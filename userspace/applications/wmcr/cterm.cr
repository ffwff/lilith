require "./gui/lib"

app = G::Application.new
window = G::Window.new(0, 0, 400, 300)
app.main_widget = window

decoration = G::WindowDecoration.new(window, "terminal")

termbox = G::Termbox.new 0, 0, 0, 0
decoration.main_widget = termbox

input_fd = IO::Pipe.new("termbox:stdin", "rwa").not_nil!
input_fd.flags = IO::Pipe::Flags::G_Write |
                 IO::Pipe::Flags::G_Read |
                 IO::Pipe::Flags::WaitRead
termbox.input_fd = input_fd

output_fd = IO::Pipe.new("termbox:stdout", "rwa").not_nil!
output_fd.flags = IO::Pipe::Flags::G_Write |
                  IO::Pipe::Flags::G_Read 
termbox.output_fd = output_fd

Process.new("/hd0/main",
            input: input_fd,
            output: output_fd,
            error: Process::Redirect::Inherit)

app.run
