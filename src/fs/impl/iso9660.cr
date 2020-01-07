module ISO9660FS
  extend self

  lib Data
    alias Int16LSB = Int16
    alias Int16MSB = Int16
    alias Int32LSB = Int32
    alias Int32MSB = Int32

    @[Packed]
    struct Int16LSBMSB
      lsb : Int16LSB
      msb : Int16MSB
    end

    @[Packed]
    struct Int32LSBMSB
      lsb : Int32LSB
      msb : Int32MSB
    end

    @[Packed]
    struct DateTime
      years_since_1900 : UInt8
      month : UInt8
      day : UInt8
      hour : UInt8
      minute : UInt8
      second : UInt8
      gmt_offset : Int8
    end

    @[Flags]
    enum Flags : UInt8
      Hidden      = 1 << 0
      Directory   = 1 << 1
      Associated  = 1 << 2
      Extended    = 1 << 3
      Permissions = 1 << 4
      Continues   = 1 << 7
    end

    @[Packed]
    struct DirectoryEntryHeader
      length : UInt8
      attr_record_length : UInt8
      extent_start : Int32LSBMSB
      extent_length : Int32LSBMSB
      time : DateTime
      flags : Flags
      unit_size : UInt8
      gap_size : UInt8
      volume_seq_no : Int16LSBMSB
      name_length : UInt8
    end

    @[Packed]
    struct RootDirectoryEntry
      length : UInt8
      attr_record_length : UInt8
      extent_start : Int32LSBMSB
      extent_length : Int32LSBMSB
      time : DateTime
      flags : Flags
      unit_size : UInt8
      gap_size : UInt8
      volume_seq_no : Int16LSBMSB
      name_length : UInt8
      name : UInt8[1]
    end

    @[Packed]
    struct VolumeDescriptor
      type : Int8
      id : UInt8[5]
      version : UInt8
      unused : UInt8
      system_id : UInt8[32]
      volume_id : UInt8[32]
      unused1 : UInt8[8]
      volume_space_size : Int32LSBMSB
      unused2 : UInt8[32]
      volume_set_size : Int16LSBMSB
      volume_seq_no : Int16LSBMSB
      logical_block_size : Int16LSBMSB
      path_table_size : Int32LSBMSB
      le_path_table : Int32LSB
      le_opt_path_table : Int32LSB
      be_path_table : Int32MSB
      be_opt_path_table : Int32MSB
      root_entry : RootDirectoryEntry
      volume_set_id : UInt8[128]
      publisher_id : UInt8[128]
      data_prep_id : UInt8[128]
      app_id : UInt8[128]
      copyright_id : UInt8[38]
      abstract_file_id : UInt8[36]
      bib_id : UInt8[37]
      volume_creation : DateTime
      volume_modification : DateTime
      volume_expiration : DateTime
      volume_effective : DateTime
      fs_version : UInt8
      unused3 : UInt8
      application_used : UInt8[512]
      reserved : UInt8[693]
    end
  end

  class Node < VFS::Node
    include VFS::Enumerable(Node)

    getter fs : FS
    getter name : String?

    @parent : Node? = nil
    property parent

    @next_node : Node? = nil
    property next_node

    @first_child : Node? = nil

    def first_child
      if directory? && !@dir_populated
        @dir_populated = true
        populate_directory
      end
      @first_child
    end

    @dir_populated = false
    getter dir_populated

    def initialize(@fs : FS, @name : String?, directory,
                   @extent_start : Int32, @extent_length : Int32)
      if directory
        @attributes |= VFS::Node::Attributes::Directory
      end
    end

    def size
      @extent_length
    end

    def read_buffer(read_size = 0, offset : UInt32 = 0, allocator : StackAllocator? = nil, &block)
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

      # buffer
      file_buffer = if allocator.nil?
                       Slice(UInt8).malloc(2048)
                     else
                       Slice(UInt8).new(allocator.not_nil!.malloc(2048).as(UInt8*), 2048)
                     end
      sector = @extent_start.to_u64 + offset.div_ceil(2048).to_u64
      offset_bytes = offset % 2048
      remaining_bytes = read_size

      # read them file
      begin
        while remaining_bytes > 0
          # read the sector
          retval = fs.device.read_sector(file_buffer.to_unsafe, sector)
          unless retval
            Serial.print "unable to read from device, returning garbage!"
            remaining_bytes = 0
            break
          end

          # yield the read buffer
          cur_buffer = Slice(UInt8).new(file_buffer.to_unsafe + offset_bytes,
                Math.min(file_buffer.size - offset_bytes, remaining_bytes.to_i32))
          yield cur_buffer
          offset += cur_buffer.size
          remaining_bytes -= cur_buffer.size
          offset_bytes = 0
        end
      ensure
        if allocator
          allocator.not_nil!.clear
        end
      end
    end

    def read(read_size = 0, offset : UInt32 = 0, allocator : StackAllocator? = nil, &block)
      read_buffer(read_size, offset, allocator) do |buffer|
        buffer.each do |byte|
          yield byte
        end
      end
    end

    def read(slice : Slice, offset : UInt32,
             process : Multiprocessing::Process? = nil) : Int32
      if offset >= size
        return VFS_EOF
      end
      VFS_WAIT
    end

    def populate_directory : Int32
      if Ide.locked?
        VFS_WAIT
      else
        iso_populate_directory
        VFS_OK
      end
    end

    private def align_even(v)
      v + (v & 1)
    end

    private def valid_char?(ch)
      '0'.ord <= ch <= '9'.ord ||
      'A'.ord <= ch <= 'Z'.ord ||
      ch == '.'.ord
    end

    private def normalize_char(ch)
      if 'A'.ord <= ch <= 'Z'.ord
        return (ch - 'A'.ord + 'a'.ord).unsafe_chr
      end
      ch.unsafe_chr
    end

    def iso_populate_directory(allocator : StackAllocator? = nil)
      @dir_populated = true
      sector = if allocator
                  Slice(UInt8).mmalloc_a 2048, allocator.not_nil!
                else
                  Slice(UInt8).malloc 2048
                end
      # Serial.print "extent length: ", @extent_length, '\n'
      remaining = @extent_length
      sector_offset = 0
      builder = String::Builder.new
      while remaining > 0
        fs.device.read_sector(sector.to_unsafe, @extent_start.to_u64 + sector_offset.to_u64)
        # Serial.print "sector: ", @extent_start + sector_offset.to_u64, '\n'

        b_offset = 0
        byte_size = Math.min(remaining, 2048)
        while b_offset < byte_size
          header = (sector.to_unsafe + b_offset).as(Data::DirectoryEntryHeader*)
          name = (header+1).as(UInt8*)

          if header.value.length == 0
            b_offset += 1
            next
          end

          if !header.value.flags.includes?(Data::Flags::Hidden) &&
              valid_char?(name[0])

            builder.reset

            slice = Slice.new(name, header.value.name_length.to_i32)
            slice.each do |ch|
              if valid_char?(ch)
                builder << normalize_char(ch)
              else
                break
              end
            end

            name = builder.to_s
            node = add_child Node.new(@fs, name,
                                      header.value.flags.includes?(Data::Flags::Directory),
                                      header.value.extent_start.lsb,
                                      header.value.extent_length.lsb)
            node.parent = self
          end

          b_offset += align_even(header.value.length)
        end

        sector_offset += 1
        remaining -= 2048
      end

      # clean up within function call
      if allocator
        allocator.not_nil!.clear
      end
    end
  end

  class FS < VFS::FS
    getter device

    @root : VFS::Node? = nil
    getter! root : VFS::Node

    @name = ""
    getter name : String

    def initialize(@device : Ata::Device)
      abort "device must be ATAPI" if @device.type != Ata::Device::Type::Atapi
      @name = @device.not_nil!.name

      sector = Pointer(Data::VolumeDescriptor).malloc_atomic
      device.read_sector(sector.as(UInt8*), 0x10)

      extent_start = sector.value.root_entry.extent_start.lsb
      extent_length = sector.value.root_entry.extent_length.lsb

      root = Node.new self, nil, true, extent_start, extent_length
      root.iso_populate_directory
      @root = root

      # setup process-local variables
      @process_allocator =
        StackAllocator.new(Pointer(Void).new(Multiprocessing::KERNEL_HEAP_INITIAL))
      @process = Multiprocessing::Process
        .spawn_kernel("[iso9660fs]",
          ->(ptr : Void*) { ptr.as(FS).process },
          self.as(Void*),
          stack_pages: 4) do |process|
        Paging.alloc_page(Multiprocessing::KERNEL_HEAP_INITIAL, true, false, 2)
      end

      @queue = VFS::Queue.new(@process)
    end

    # queue
    getter queue

    protected def process
      while true
        if (msg = @queue.not_nil!.dequeue)
          node = msg.vfs_node.as!(Node)
          case msg.type
          when VFS::Message::Type::Read
            node.read_buffer(msg.slice_size,
              msg.file_offset.to_u32,
              allocator: @process_allocator) do |buffer|
              msg.respond(buffer)
            end
            msg.unawait
          when VFS::Message::Type::Spawn
          when VFS::Message::Type::PopulateDirectory
          end
        else
          Multiprocessing.sleep_disable_gc
        end
      end
    end

  end

end
