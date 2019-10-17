{% if false %}
class Iso9660FS < VFS
  @root : VFSNode? = nil

  def root : VFSNode
    @root.not_nil!
  end

  def name
    device.not_nil!.name.not_nil!
  end

  getter device

  def initialize(@device : AtaDevice)
    Console.puts "initializing ISO9660 filesystem\n"

    panic "device must be ATAPI" if @device.type != Type::Atapi

    # TODO

  end
end
{% end %}
