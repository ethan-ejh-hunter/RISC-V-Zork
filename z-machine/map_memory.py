import struct
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description="Map Z-machine memory layout")
    parser.add_argument("file", nargs="?", default="zork1.z3", help="Z-machine game file (default: zork1.z3)")
    args = parser.parse_args()

    try:
        with open(args.file, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        print(f"Error: {args.file} not found.")
        sys.exit(1)

    if len(data) < 64:
        print("Error: File too small.")
        sys.exit(1)

    # Header parsing (Big Endian)
    version = data[0]
    high_mem_base = struct.unpack(">H", data[0x04:0x06])[0]
    init_pc = struct.unpack(">H", data[0x06:0x08])[0]
    dictionary_addr = struct.unpack(">H", data[0x08:0x0A])[0]
    object_table_addr = struct.unpack(">H", data[0x0A:0x0C])[0]
    globals_addr = struct.unpack(">H", data[0x0C:0x0E])[0]
    static_mem_base = struct.unpack(">H", data[0x0E:0x10])[0]
    abbrev_table_addr = struct.unpack(">H", data[0x18:0x1A])[0]
    file_length_factor = 2 if version <= 3 else 4 if version <= 5 else 8
    file_len_raw = struct.unpack(">H", data[0x1A:0x1C])[0]
    calculated_length = file_len_raw * file_length_factor

    print(f"Z-Machine Version: {version}")
    print(f"File Size: {len(data)} bytes")
    if file_len_raw > 0:
        print(f"Header File Length: {calculated_length} bytes")

    print("\nMemory Map:")
    print("-" * 40)
    print(f"{'Structure':<20} | {'Address':<10}")
    print("-" * 40)
    
    # Sort addresses to print in order? Or just list them? 
    # Listing key structures is probably better.
    
    # Dynamic Memory (0 to Static Base)
    print(f"{'Dynamic Memory End':<20} | 0x{static_mem_base:04X}")
    
    # Key Tables
    print(f"{'Dictionary':<20} | 0x{dictionary_addr:04X}")
    print(f"{'Object Table':<20} | 0x{object_table_addr:04X}")
    print(f"{'Globals Table':<20} | 0x{globals_addr:04X}")
    print(f"{'Abbreviations':<20} | 0x{abbrev_table_addr:04X}") # V3 commonly
    
    print(f"{'Static Memory Base':<20} | 0x{static_mem_base:04X}")
    print(f"{'High Memory Base':<20} | 0x{high_mem_base:04X}")
    print(f"{'Initial PC':<20} | 0x{init_pc:04X}")

    if version == 3:
         print("\nNote: Standard V3 Memory Layout usually follows:")
         print("Header -> Abbrevs -> Dict -> Objects -> Globals -> Static Memory -> High Memory")

if __name__ == "__main__":
    main()
