startup = [
  # ["pape", "/hd0/share/papes/violet.png"],
  ["cterm"],
  ["cbar"],
]
# FIXME: wait for wm to finish setting up
sleep 1
startup.each do |args|
  program = args.shift.not_nil!
  Process.new program, args,
    input: Process::Redirect::Inherit,
    output: Process::Redirect::Inherit,
    error: Process::Redirect::Inherit
end
