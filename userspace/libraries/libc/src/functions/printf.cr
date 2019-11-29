private def internal_printf(args : VaList, format : UInt8*, &block) : LibC::Int
  written = 0
  while format.value != 0
    case format.value.unsafe_chr
    when '0'
      return written
    when 'c'
      format += 1
      ch = args.next(LibC::Int)
      return written if (retval = yield Tuple.new(1, ch)) == 0
      written += ch
    end
  end
  written
end
