fun strdup(str : LibC::String) : LibC::String
    if str.null?
        return Pointer(UInt8).null
    end
    new_str = calloc(LibC.strlen(str) + 1, 1).as(LibC::String)
    LibC.strcpy new_str, str
    new_str
end