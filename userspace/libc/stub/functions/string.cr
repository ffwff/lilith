fun strdup(str : LibC::String) : LibC::String
    new_str = calloc(LibC.strlen(str) + 1, 1).as(LibC::String)
    LibC.strcpy new_str, str
    new_str
end