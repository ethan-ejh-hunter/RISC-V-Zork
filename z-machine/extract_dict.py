import struct
import argparse
import sys
from find_test_strings import ZStringDecoder

def main():
    parser = argparse.ArgumentParser(description="Extract Z-machine dictionary words and addresses")
    parser.add_argument("file", nargs="?", default="zork1.z3", help="Z-machine game file (default: zork1.z3)")
    args = parser.parse_args()

    try:
        with open(args.file, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        print(f"Error: {args.file} not found.")
        sys.exit(1)

    if len(data) < 64:
        print("Error: File too small to be a valid Z-machine file.")
        sys.exit(1)

    # Dictionary address is at 0x08 in the header
    dict_base = struct.unpack(">H", data[0x08:0x0A])[0]
    
    print(f"Dictionary Base Address: 0x{dict_base:04X}")

    # The dictionary starts with a list of word separators.
    # Byte 0 contains the number of separators (n).
    num_separators = data[dict_base]
    separators = []
    for i in range(num_separators):
        separators.append(chr(data[dict_base + 1 + i]))
    
    print(f"Word Separators ({num_separators}): {repr(separators)}")

    # After the separators is the data for the dictionary entries.
    # A single byte specifies the length of each entry (normally 7 in V3: 4 bytes text + 3 bytes data).
    # Then a 2-byte word specifies the number of entries.
    entry_header_start = dict_base + 1 + num_separators
    entry_length = data[entry_header_start]
    num_entries = struct.unpack(">H", data[entry_header_start + 1:entry_header_start + 3])[0]

    print(f"Entry Length: {entry_length} bytes")
    print(f"Number of Entries: {num_entries}")
    print("-" * 60)
    print(f"{'Index':<6} | {'Addr':<6} | {'Hex (Z50)':<12} | {'Word'}")
    print("-" * 60)

    entries_start = entry_header_start + 3
    decoder = ZStringDecoder(data)

    for i in range(num_entries):
        entry_addr = entries_start + (i * entry_length)
        
        if entry_addr + entry_length > len(data):
            print("Reached end of file unexpectedly.")
            break
            
        # V3 dictionary entries have 4 bytes of encoded text
        z50_word1, z50_word2 = struct.unpack(">HH", data[entry_addr:entry_addr + 4])
        
        # To decode it, we can just feed the 4 bytes to the ZStringDecoder
        # But we need to make sure the end bit is artificially set if it's not
        # Actually, dictionary words don't always have the MSB of the second word set if they were exactly 6 chars.
        # But the decoder expects a 0x8000 end bit. 
        # We can extract the Z-chars directly using the decoder's helper
        z_chars = decoder.get_z_chars(z50_word1) + decoder.get_z_chars(z50_word2)
        
        # We need to manually run the decode loop on these 6 chars
        word_text = ""
        alphabet = 0
        shift = False
        i = 0
        
        while i < len(z_chars):
            char = z_chars[i]
            if char == 0:
                word_text += " "
                if shift: alphabet = 0; shift = False
            elif 1 <= char <= 3:
                # Abbreviation - shouldn't happen in dictionary words usually, but just in case
                if i + 1 < len(z_chars):
                    word_text += decoder.expand_abbreviation(char - 1, z_chars[i+1])
                    i += 1
                if shift: alphabet = 0; shift = False
            elif char == 4:
                alphabet = 1; shift = True
            elif char == 5:
                alphabet = 2; shift = True
            elif char == 6 and alphabet == 2:
                if i + 2 < len(z_chars):
                    zscii = (z_chars[i+1] << 5) | z_chars[i+2]
                    word_text += chr(zscii)
                    i += 2
                if shift: alphabet = 0; shift = False
            else:
                if char >= 6:
                    if alphabet == 0: word_text += decoder.A0[char-6]
                    elif alphabet == 1: word_text += decoder.A1[char-6]
                    elif alphabet == 2: word_text += decoder.A2[char-6]
                if shift: alphabet = 0; shift = False
            i += 1
            
        hex_repr = f"{z50_word1:04X} {z50_word2:04X}"
        print(f"{i:<6} | 0x{entry_addr:04X} | {hex_repr}    | {word_text}")

if __name__ == "__main__":
    main()
