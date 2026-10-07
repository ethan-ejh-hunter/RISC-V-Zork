import sys

def get_word(mem, addr):
    return (mem[addr] << 8) | mem[addr+1]

def decode_zscii(mem, addr):
    # Very simple ZSCII decoder for object names (usually just alphabet 0)
    # Each word is 3 characters. Bit 15 is end-of-string. Bits 14-10, 9-5, 4-0 are chars.
    res = ""
    while True:
        w = get_word(mem, addr)
        addr += 2
        for shift in [10, 5, 0]:
            c = (w >> shift) & 0x1F
            if c >= 6:
                res += chr(c + 97 - 6)
            elif c == 5:
                res += " "
        if w & 0x8000:
            break
    return res

def main():
    with open('zork1.z3', 'rb') as f:
        mem = f.read()

    obj_table_base = get_word(mem, 0x0A)
    default_props_end = obj_table_base + 31 * 2
    
    # Check 255 objects
    for obj_num in range(1, 256):
        obj_addr = default_props_end + (obj_num - 1) * 9
        props_addr = get_word(mem, obj_addr + 7)
        
        text_len = mem[props_addr]
        if text_len > 0:
            name = decode_zscii(mem, props_addr + 1)
            if "mailbox" in name:
                print(f"Object {obj_num}: '{name}' at addr {hex(obj_addr)}")
                # Dump attributes (first 4 bytes)
                attrs = mem[obj_addr:obj_addr+4]
                print(f"  Initial Attributes: {[hex(b) for b in attrs]}")

if __name__ == "__main__":
    main()
