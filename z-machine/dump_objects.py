import struct
import argparse
import sys
from find_test_strings import ZStringDecoder

def main():
    parser = argparse.ArgumentParser(description="Dump Z-machine object table hierarchy")
    parser.add_argument("file", nargs="?", default="zork1.z3", help="Z-machine game file (default: zork1.z3)")
    args = parser.parse_args()

    try:
        with open(args.file, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        print(f"Error: {args.file} not found.")
        sys.exit(1)

    # Read Object Table address from header (0x0A)
    # Z-machine standard: header is at least 64 bytes.
    if len(data) < 64:
        print("Error: File too small to be a valid Z-machine file.")
        sys.exit(1)

    obj_table_base = struct.unpack(">H", data[0x0A:0x0C])[0]
    obj_table_base = struct.unpack(">H", data[0x0A:0x0C])[0]
    
    # For Version 3, standard defaults table is 31 words (62 bytes)
    # The object entries start immediately after the property defaults table.
    obj_entries_start = obj_table_base + 62

    print(f"Object Table Base:      0x{obj_table_base:04X}")
    print(f"  Property Defaults:    0x{obj_table_base:04X} - 0x{obj_entries_start-1:04X} (62 bytes)")
    print(f"  Object Entries Start: 0x{obj_entries_start:04X}")
    
    # V3 Object Entry Format (9 bytes):
    # Bytes 0-3: Attributes (32 bits)
    # Byte 4: Parent object number
    # Byte 5: Sibling object number
    # Byte 6: Child object number
    # Bytes 7-8: Property table address
    
    
    entry_size = 9
    max_objects = 255 # V3 supports up to 255 objects (1-255)

    decoder = ZStringDecoder(data)

    print(f"{'ID':<4} | {'Addr':<6} | {'Parent':<6} | {'Sibling':<7} | {'Child':<5} | {'Prop Addr':<9} | {'Attributes (Hex)':<16} | {'Name'}")
    print("-" * 110)

    # Dictionary to verify hierarchy validity later if needed
    objects = {}

    for obj_id in range(1, max_objects + 1):
        offset = obj_entries_start + (obj_id - 1) * entry_size
        
        # Safety check for bounds
        if offset + entry_size > len(data):
            break

        # Read fields
        # Attributes are 4 bytes.
        attributes = struct.unpack(">I", data[offset:offset+4])[0]
        
        parent = data[offset + 4]
        sibling = data[offset + 5]
        child = data[offset + 6]
        
        
        prop_addr = struct.unpack(">H", data[offset+7:offset+9])[0]
        
        # Read object name
        # First byte at prop_addr is the length of the short name in words
        text_len = data[prop_addr]
        if text_len > 0:
            # String starts at prop_addr + 1
            name, _ = decoder.decode(prop_addr + 1)
        else:
            name = "<unnamed>"

        objects[obj_id] = {
            "p": parent,
            "s": sibling,
            "c": child
        }

        print(f"{obj_id:<4} | 0x{offset:04X} | {parent:<6} | {sibling:<7} | {child:<5} | 0x{prop_addr:04X}    | {attributes:08X}         | {name}")

        # Dump properties
        # Skip name
        prop_ptr = prop_addr + 1 + (text_len * 2)
        
        while True:
            size_byte = data[prop_ptr]
            if size_byte == 0:
                break
            
            prop_len = (size_byte >> 5) + 1
            prop_num = size_byte & 0x1F
            
            prop_data = data[prop_ptr + 1 : prop_ptr + 1 + prop_len]
            prop_hex = " ".join([f"{b:02X}" for b in prop_data])
            
            print(f"       [0x{prop_ptr:04X}] Prop #{prop_num:<2} (Size {prop_len}): {prop_hex}")
            
            prop_ptr += 1 + prop_len


if __name__ == "__main__":
    main()
