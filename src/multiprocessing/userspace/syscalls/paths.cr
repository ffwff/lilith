module Syscall::Path
  extend self

  # Splits a path into segments delimited by /
  def parse_path_into_segments(path, &block)
    i = 0
    pslice_start = 0
    while i < path.size
      # Serial.print path[i].unsafe_chr
      if path[i] == '/'.ord
        # ignore multi occurences of slashes
        if i - pslice_start > 0
          # search for root subsystems
          yield path[pslice_start..i]
        end
        pslice_start = i + 1
      end
      i += 1
    end
    if path.size - pslice_start > 0
      yield path[pslice_start..path.size]
    end
  end

  # Parses a path into a VFS node
  def parse_path_into_vfs(path : Slice(UInt8), args : Syscall::Arguments,
                          cw_node : VFS::Node? = nil,
                          create = false,
                          create_options = 0)
    vfs_node : VFS::Node? = nil
    return if path.size < 1
    if path[0] != '/'.ord
      vfs_node = cw_node
    end
    parse_path_into_segments(path) do |segment|
      if vfs_node.nil? # no path specifier
        unless vfs_node = RootFS.find_root(segment)
          return
        end
      elsif segment == "."
        # ignored
      elsif segment == ".."
        vfs_node = vfs_node.parent
      else
        if vfs_node.directory? && !vfs_node.dir_populated
          case vfs_node.populate_directory
          when VFS_OK
            # ignored
          when VFS_WAIT
            vfs_node.fs.queue.not_nil!
              .enqueue(VFS::Message.new(vfs_node, args.process))
            args.process.sched_data.status = Multiprocessing::Scheduler::ProcessData::Status::WaitIo
            Multiprocessing::Scheduler.switch_process(args.frame)
          end
        end
        cur_node = vfs_node.open_cached?(segment) ||
                   vfs_node.open(segment, args.process)
        if cur_node.nil? && create
          cur_node = vfs_node.create(segment, args.process, create_options)
        end
        return if cur_node.nil?
        vfs_node = cur_node
      end
    end
    vfs_node
  end

  # Append two path slices together
  def append_paths(path, src_path, cw_node)
    return nil if path.size < 1
    builder = String::Builder.new

    if path[0] == '/'.ord
      vfs_node = nil
      builder << "/"
    else
      vfs_node = cw_node
      builder << src_path
    end

    parse_path_into_segments(path) do |segment|
      if segment == "."
        # ignored
      elsif segment == ".."
        # pop
        if !vfs_node.nil?
          if vfs_node.not_nil!.parent.nil?
            return nil
          end
          while builder.bytesize > 1
            builder.back 1
            if builder.buffer[builder.bytesize] == '/'.ord
              break
            end
          end
          vfs_node = vfs_node.not_nil!.parent
        end
      else
        builder << "/"
        builder << segment
        if vfs_node.nil?
          unless vfs_node = RootFS.find_root(segment)
            return
          end
        elsif (vfs_node = vfs_node.not_nil!.open(segment)).nil?
          return nil
        end
      end
    end

    {builder.to_s, vfs_node}
  end
end
