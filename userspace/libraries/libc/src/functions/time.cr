fun gmtime
  abort
end

fun localtime
  abort
end

fun clock : LibC::ULong
	# TODO
  0u32
end

fun difftime(t1 : LibC::ULong, t0 : LibC::ULong) : Float64
	# TODO
	0.0f64
end

fun mktime(timep : Void*) : LibC::ULong
	# TODO
  0u32
end

fun strftime(s : LibC::String, max : LibC::SizeT, format : LibC::String, tm : Void*) : LibC::SizeT
	0u32
end