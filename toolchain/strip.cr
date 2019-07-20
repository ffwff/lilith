require "llvm"

lib LibLLVM
    fun delete_function = LLVMDeleteFunction(func : ValueRef)
end

file = LLVM::MemoryBuffer.from_file(ARGV[0])
ctx = LLVM::Context.new
mod = ctx.parse_ir file
LibLLVM.delete_function(mod.functions["__crystal_main"])
mod.write_bitcode_to_file(ARGV[1])