///|
pub fn compile_file(
  input_path : String,
  output_path : String,
) -> Result[Unit, String] {
  // Read input file
  let source = @fs.read_file_to_string(input_path) catch {
    e => return Err("Failed to read input file: \{e}")
  }

  // Tokenize
  let tokens = tokenize(source)

  // Parse into AST
  let ast = parse(tokens)

  // Generate x86_64 code
  let code = codegen(ast)

  // Header is 64 + 56 = 120 bytes (0x78)
  // Code should start at 0x401000 (like GCC -nostdlib -s)
  // File offset for 0x1000
  // Padding: 0x1000 - 0x78 = 0xF88 bytes
  let padding_len = 0x1000 - 0x78
  let padding : Array[Byte] = Array::make(padding_len, 0x00B)

  let header : Array[Byte] = [
    // ELF header (64 bytes)
    0x7F, 0x45, 0x4C, 0x46, // magic
     0x02, // 64-bit
     0x01, // little endian
     0x01, // version
     0x00, // SYS V ABI
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // padding
     0x02, 0x00, // e_type = ET_EXEC
     0x3E, 0x00, // e_machine = x86-64
     0x01, 0x00, 0x00, 0x00, // e_version
     0x00, 0x10, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, // e_entry = 0x401000
     0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // e_phoff = 64
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // e_shoff = 0
     0x00, 0x00, 0x00, 0x00, // e_flags
     0x40, 0x00, // e_ehsize = 64
     0x38, 0x00, // e_phentsize = 56
     0x01, 0x00, // e_phnum = 1
     0x00, 0x00, // e_shentsize
     0x00, 0x00, // e_shnum
     0x00, 0x00, // e_shstrndx

    // Program header (56 bytes)
     0x01, 0x00, 0x00, 0x00, // p_type = PT_LOAD
     0x07, 0x00, 0x00, 0x00, // p_flags = PF_X | PF_W | PF_R
     0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // p_offset = 0x1000
     0x00, 0x10, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, // p_vaddr = 0x401000
     0x00, 0x10, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, // p_paddr = 0x401000
  ]

  // Calculate code size and pad to page boundary
  let code_len = code.length()
  let padded_code_len = (code_len + 0xFFF) & 0xFFFFF000

  // Header is 96 bytes (ELF header 64 + partial program header 32)
  // phdr_extra is 24 bytes (p_filesz, p_memsz, p_align)
  // Total: 120 bytes
  // Padding: 0x1000 - 120 = 3976 bytes (0xF88)
  let padding_len = 0x1000 - 120

  // Create phdr_bytes - write padded_code_len as little-endian bytes
  let mut phdr_all : Array[Byte] = []

  // p_filesz (8 bytes) - padded_code_len in little-endian
  // For a 32-bit Int, we only need the lower 4 bytes; upper 4 are zero
  phdr_all = phdr_all +
    [
      (padded_code_len & 0xFF).to_byte(),
      ((padded_code_len >> 8) & 0xFF).to_byte(),
      ((padded_code_len >> 16) & 0xFF).to_byte(),
      ((padded_code_len >> 24) & 0xFF).to_byte(),
      0x00,
      0x00,
      0x00,
      0x00, // Upper 4 bytes are always 0 for 32-bit values
    ]

  // p_memsz (8 bytes) - same as filesz
  phdr_all = phdr_all +
    [
      (padded_code_len & 0xFF).to_byte(),
      ((padded_code_len >> 8) & 0xFF).to_byte(),
      ((padded_code_len >> 16) & 0xFF).to_byte(),
      ((padded_code_len >> 24) & 0xFF).to_byte(),
      0x00,
      0x00,
      0x00,
      0x00,
    ]

  // p_align (8 bytes) = 0x1000
  phdr_all = phdr_all + [0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

  let phdr_bytes = Bytes::from_array(phdr_all)
  let header_bytes = Bytes::from_array(header)
  let padding : Array[Byte] = Array::make(padding_len, 0x00B)
  let padding_bytes = Bytes::from_array(padding)

  // Pad code to match padded_code_len
  let code_padding_len = padded_code_len - code_len
  let code_padding : Array[Byte] = Array::make(code_padding_len, 0x00)
  let code_bytes = code + Bytes::from_array(code_padding)

  let result = header_bytes + phdr_bytes + padding_bytes + code_bytes

  try {
    @fs.write_bytes_to_file(output_path, result)
    Ok(())
  } catch {
    e => Err("Failed to write output file: \\{e}")
  }
}
