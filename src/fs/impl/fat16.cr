private lib Fat16Structs
  @[Packed]
  struct Fat16BootSector
    jmp : UInt8[3]
    oem : UInt8[8]
    sector_size : UInt16
    sectors_per_cluster : UInt8
    reserved_sectors : UInt16
    number_of_fats : UInt8
    root_dir_entries : UInt16
    total_sectors_short : UInt16
    media_descriptor : UInt8
    fat_size_sectors : UInt16
    sectors_per_track : UInt16
    number_of_heads : UInt16
    hidden_sectors : UInt32
    total_sectors_long : UInt32

    drive_number : UInt8
    current_head : UInt8
    boot_signature : UInt8
    volume_id : UInt32
    volume_label : UInt8[11]
    fs_type : UInt8[8]
    boot_code : UInt8[448]
    boot_sector_signature : UInt16
  end

  @[Packed]
  struct Fat16Entry
    name : UInt8[8]
    ext : UInt8[3]
    attributes : UInt8
    reserved : UInt8[10]
    modify_time : UInt16
    modify_date : UInt16
    starting_cluster : UInt16
    file_size : UInt32
  end
end

# entry attributes
private def entry_exists?(entry : Fat16Structs::Fat16Entry)
  # 0x0 : null entry, 0xE5 : deleted
  entry.name[0] != 0x0 && entry.name[0] != 0xE5
end

private def entry_volume_label?(entry : Fat16Structs::Fat16Entry)
  (entry.attributes & 0x08) == 0x08
end

private def entry_file?(entry : Fat16Structs::Fat16Entry)
  (entry.attributes & 0x18) == 0
end

private def entry_dir?(entry : Fat16Structs::Fat16Entry)
  (entry.attributes & 0x18) == 0x10
end

# entry naming
private def name_from_entry(entry)
  # name
  name_len = 7
  while name_len >= 0
    break if entry.name[name_len] != ' '.ord.to_u8
    name_len -= 1
  end

  # extension
  ext_len = 2
  while ext_len >= 0
    break if entry.ext[ext_len] != ' '.ord.to_u8
    ext_len -= 1
  end

  # filename
  if ext_len > 0
    fname = GcString.new(name_len + 2 + ext_len + 1)
  else
    fname = GcString.new(name_len + 1)
  end
  (name_len + 1).times do |i|
    if entry.name[i] >= 'A'.ord && entry.name[i] <= 'Z'.ord
      # to lower case
      fname[i] = entry.name[i] - 'A'.ord + 'a'.ord
    else
      fname[i] = entry.name[i]
    end
  end
  if ext_len > 0
    name_len += 1
    fname[name_len] = '.'.ord.to_u8
    name_len += 1
    (ext_len + 1).times do |i|
      if entry.ext[i] >= 'A'.ord && entry.ext[i] <= 'Z'.ord
        # to lower case
        fname[name_len + i] = entry.ext[i] - 'A'.ord + 'a'.ord
      else
        fname[name_len + i] = entry.ext[i]
      end
    end
  end

  fname
end

private class Fat16Node < VFSNode
  @parent : Fat16Node? = nil
  property parent

  @next_node : Fat16Node? = nil
  property next_node

  @name : GcString? = nil
  property name

  @first_child : Fat16Node? = nil
  def first_child
    if @directory && !@dir_populated
      @dir_populated = true
      populate_directory
    end
    @first_child
  end

  @size = 0u32
  getter size

  # file system specific
  @starting_cluster = 0u32
  getter starting_cluster

  @directory = false
  @dir_populated = false

  def directory?
    @directory
  end

  getter fs

  def initialize(@fs : Fat16FS, @name = nil, @directory = false,
                 @next_node = nil, @first_child = nil,
                 @size = 0u32, @starting_cluster = 0u32)
  end

  # children
  def each_child(&block)
    if @directory && !@dir_populated
      @dir_populated = true
      populate_directory
    end
    node = first_child
    while !node.nil?
      yield node.not_nil!
      node = node.next_node
    end
  end

  def add_child(child : Fat16Node)
    if @first_child.nil?
      # first node
      child.next_node = nil
      @first_child = child
    else
      # middle node
      child.next_node = @first_child
      @first_child = child
    end
    child.parent = self
    child
  end

  # read
  private def sector_for(cluster)
    fs.fat_sector + cluster / fs.fat_sector_size
  end

  private def ent_for(cluster)
    cluster % fs.fat_sector_size
  end

  private def read_fat_table(fat_table, cluster, last_sector? = -1)
    fat_sector = sector_for cluster
    if last_sector? == fat_sector
      return fat_sector
    end

    fs.device.read_sector(fat_table, fat_sector.to_u64)
    fat_sector
  end

  def read(read_size = 0, offset = 0, allocator = nil, &block)
    return if directory?

    # check arguments
    if read_size == 0
      read_size = size
    elsif read_size < 0
      return
    end
    if offset + read_size > size
      read_size = size - offset
    end

    # setup
    fat_table = if allocator
      sz = fs.fat_sector_size
      Slice(UInt16).new(allocator.not_nil!.malloc(sz * sizeof(UInt16)).as(UInt16*), sz)
    else
      Slice(UInt16).mmalloc(fs.fat_sector_size)
    end
    fat_sector = read_fat_table fat_table, starting_cluster

    cluster = starting_cluster
    remaining_bytes = read_size

    # skip clusters
    offset_factor = fs.sectors_per_cluster * 512
    offset_clusters = offset / offset_factor
    while offset_clusters > 0 && cluster < 0xFFF8
      fat_sector = read_fat_table fat_table, cluster, fat_sector
      cluster = fat_table[ent_for cluster]
      offset_clusters -= 1
    end
    offset_bytes = offset % offset_factor

    # read file
    file_buffer = if allocator.nil?
      Slice(UInt16).mmalloc(256)
    else
      sz = 256
      Slice(UInt16).new(allocator.not_nil!.malloc(sz * sizeof(UInt16)).as(UInt16*), sz)
    end 
    while remaining_bytes > 0 && cluster < 0xFFF8
      sector = ((cluster.to_u64 - 2) * fs.sectors_per_cluster) + fs.data_sector
      read_sector = 0
      while remaining_bytes > 0 && read_sector < fs.sectors_per_cluster
        unless fs.device.read_sector(file_buffer, sector + read_sector)
          panic "unable to read!"
        end
        file_buffer.each do |word|
          u8 = (word >> 8) & 0xFF
          u8_1 = word & 0xFF
          if remaining_bytes > 0
            if offset_bytes > 0
              offset_bytes -= 1
            else
              yield u8_1.to_u8
              remaining_bytes -= 1
            end
            if remaining_bytes > 0
              if offset_bytes > 0
                offset_bytes -= 1
              else
                yield u8.to_u8
                remaining_bytes -= 1
              end
            else
              break
            end
          else
            break
          end
        end
        read_sector += 1
      end
      fat_sector = read_fat_table fat_table, cluster, fat_sector
      cluster = fat_table[ent_for cluster]
    end

    # clean up within function call
    if allocator.nil?
      file_buffer.mfree
      fat_table.mfree
    else
      allocator.not_nil!.clear
    end
  end

  #
  private def populate_directory
    fat_table = Slice(UInt16).mmalloc fs.fat_sector_size
    fat_sector = read_fat_table fat_table, starting_cluster

    cluster = starting_cluster
    end_directory = false

    entries = Slice(Fat16Structs::Fat16Entry).mmalloc 16

    while cluster < 0xFFF8
      sector = ((cluster.to_u64 - 2) * fs.sectors_per_cluster) + fs.data_sector
      read_sector = 0
      while read_sector < fs.sectors_per_cluster
        fs.device.read_sector(entries.to_unsafe.as(UInt16*), sector + read_sector)
        entries.each do |entry|
          load_entry(entry)
        end
        read_sector += 1
      end

      break if end_directory
      fat_sector = read_fat_table fat_table, cluster, fat_sector
      cluster = fat_table[ent_for cluster]
    end

    entries.mfree
    fat_table.mfree
  end

  def open(path : Slice) : VFSNode?
    return unless directory?
    each_child do |node|
      if node.name == path
        return node
      end
    end
  end

  def read(slice : Slice, offset : UInt32,
           process : Multiprocessing::Process? = nil) : Int32
    if offset >= @size
      return VFS_EOF
    end
    VFS_WAIT
  end

  def spawn(udata : Multiprocessing::Process::UserData) : Int32
    VFS_WAIT
  end

  def write(slice : Slice, offset : UInt32,
            process : Multiprocessing::Process? = nil) : Int32
    VFS_ERR
  end

  # entry loading
  def load_entry(entry)
    return if !entry_exists? entry
    return if entry_volume_label? entry
    unless 0x20 <= entry.name[0] && entry.name[0] <= 0x7e
      # FIXME: the driver sometimes reads garbage entries
      return
    end
    if entry_file? entry
      load_file_entry entry
    elsif entry_dir? entry
      load_dir_entry entry
    end
  end

  private def load_file_entry(entry)
    node = Fat16Node.new(fs, name_from_entry(entry),
      starting_cluster: entry.starting_cluster.to_u32,
      size: entry.file_size)
    add_child node
  end

  private def load_dir_entry(entry)
    name = name_from_entry(entry)
    return if name == "." || name == ".."
    node = Fat16Node.new(fs, name, true,
      starting_cluster: entry.starting_cluster.to_u32,
      size: entry.file_size)
    add_child node
  end
end

class Fat16FS < VFS
  FS_TYPE = "FAT16   "

  def root
    @root.not_nil!
  end

  @fat_sector = 0u32
  getter fat_sector
  @fat_sector_size = 0
  getter fat_sector_size

  @data_sector = 0u64
  getter data_sector

  @sectors_per_cluster = 0u64
  getter sectors_per_cluster

  # impl
  def name
    device.not_nil!.name.not_nil!
  end

  getter device

  def initialize(@device : AtaDevice, partition)
    Console.puts "initializing FAT16 filesystem\n"

    panic "device must be ATA" if @device.type != AtaDevice::Type::Ata

    bs = Pointer(Fat16Structs::Fat16BootSector).mmalloc

    device.read_sector(bs.as(UInt16*), partition.first_sector.to_u64)
    idx = 0
    bs.value.fs_type.each do |ch|
      panic "only FAT16 is accepted" if ch != FS_TYPE[idx]
      idx += 1
    end

    @fat_sector = partition.first_sector + bs.value.reserved_sectors
    @fat_sector_size = bs.value.sector_size.to_i32 / sizeof(UInt16)

    root_dir_sectors = ((bs.value.root_dir_entries * 32) + (bs.value.sector_size - 1)) / bs.value.sector_size

    sector = (fat_sector + bs.value.fat_size_sectors * bs.value.number_of_fats).to_u64
    @data_sector = sector + root_dir_sectors
    @sectors_per_cluster = bs.value.sectors_per_cluster.to_u64

    # load root directory
    @root = Fat16Node.new self, nil, true
    entries = Slice(Fat16Structs::Fat16Entry).mmalloc 16

    bs.value.root_dir_entries.times do |i|
      break if sector + i > @data_sector
      device.read_sector(entries.to_unsafe.as(UInt16*), sector + i)
      entries.each do |entry|
        if pointerof(entry).as(UInt8*)[0] == 0
          break
        end
        root.load_entry entry
      end
    end

    # cleanup
    entries.mfree
    bs.mfree

    # setup process-local variables
    @process_allocator =
      StackAllocator.new(Pointer(Void).new(Multiprocessing::KERNEL_HEAP_INITIAL))
    @process = Multiprocessing::Process
      .spawn_kernel(GcString.new("[fat16fs]"),
                    ->(ptr : Void*) { ptr.as(Fat16FS).process },
                    self.as(Void*),
                    stack_pages: 4) do |process|
      Paging.alloc_page_pg(Multiprocessing::KERNEL_HEAP_INITIAL, true, false)
    end

    @queue = VFSQueue.new(@process)
  end

  # queue
  getter queue

  # process
  @process_msg : VFSMessage? = nil
  protected def process
    while true
      @process_msg = @queue.not_nil!.dequeue
      unless (msg = @process_msg).nil?
        fat16_node = msg.vfs_node.unsafe_as(Fat16Node)
        case msg.type
        when VFSMessage::Type::Read
          fat16_node.read(msg.slice_size,
                          msg.file_offset,
                          allocator: @process_allocator) do |ch|
            msg.respond(ch)
          end
          msg.unawait
        when VFSMessage::Type::Write
          # TODO
          msg.unawait
        when VFSMessage::Type::Spawn
          udata = msg.udata.not_nil!
          case (retval = ElfReader.load_from_kernel_thread(fat16_node, @process_allocator.not_nil!))
          when ElfReader::Result
            retval = retval.as(ElfReader::Result)
            pid = Multiprocessing::Process
              .spawn_user_drv(
                retval.initial_ip,
                retval.heap_start,
                msg.udata.not_nil!,
                retval.mmap_list)
            if msg.process
              msg.unawait(pid)
            end
          else
            panic "unable to execute ", retval, "\n"
          end
          @process_allocator.not_nil!.clear
        end
      else
        Multiprocessing.sleep_drv
      end
    end
  end
end
