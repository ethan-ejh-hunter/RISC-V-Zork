import struct
import argparse
# this was NOT written by me (fully AI, since it's only tooling, and I 
# don't really care enough to write it myself)
# ALL of the assembly code was written by me.
class ZStringDecoder:
    def __init__(self, data):
        self.data = data
        self.abbrevs_start = struct.unpack(">H", data[0x18:0x1a])[0]
        self.A0 = "abcdefghijklmnopqrstuvwxyz"
        self.A1 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        self.A2 = " \n0123456789.,!?_#'\"/\\-:()"

    def get_z_chars(self, word):
        c1 = (word >> 10) & 0x1F
        c2 = (word >> 5) & 0x1F
        c3 = word & 0x1F
        return [c1, c2, c3]

    def decode(self, offset, verbose=False, depth=0):
        z_chars = []
        raw_words = []
        current_offset = offset
        
        # Read all Z-characters first
        while True:
            word = struct.unpack(">H", self.data[current_offset:current_offset+2])[0]
            raw_words.append((current_offset, word))
            chars = self.get_z_chars(word)
            z_chars.extend(chars)
            if word & 0x8000:
                break
            current_offset += 2
            
        byte_len = current_offset + 2 - offset
        
        # Calculate meanings for verbose output
        meanings = [""] * len(z_chars)
        m_alphabet = 0
        m_shift = False
        
        mi = 0
        while mi < len(z_chars):
            char = z_chars[mi]
            desc = ""
            
            if char == 0:
                desc = "space"
                if m_shift: m_alphabet = 0; m_shift = False
            elif 1 <= char <= 3:
                desc = "abbrev"
                if mi + 1 < len(z_chars):
                    meanings[mi+1] = f"idx {z_chars[mi+1]}"
                    mi += 1 # skip next
                if m_shift: m_alphabet = 0; m_shift = False
            elif char == 4:
                desc = "shift A1"
                m_alphabet = 1; m_shift = True
            elif char == 5:
                desc = "shift A2"
                m_alphabet = 2; m_shift = True
            elif char == 6 and m_alphabet == 2:
                desc = "ZSCII-high"
                if mi + 2 < len(z_chars):
                    meanings[mi+1] = "ZSCII-lo"
                    # Combine for display
                    high = z_chars[mi+1]
                    low = z_chars[mi+2]
                    zscii = (high << 5) | low
                    meanings[mi+2] = f"'{chr(zscii)}'"
                    mi += 2
                if m_shift: m_alphabet = 0; m_shift = False
            else:
                # Map char
                if char >= 6:
                     # Re-use map_char logic or duplicate minimal
                    if m_alphabet == 0: val = self.A0[char-6]
                    elif m_alphabet == 1: val = self.A1[char-6]
                    elif m_alphabet == 2: val = self.A2[char-6]
                    else: val = "?"
                    desc = f"'{val}'"
                
                if m_shift: m_alphabet = 0; m_shift = False
            
            if meanings[mi] == "":
                meanings[mi] = desc
            mi += 1

        
        # Now decode the stream of Z-characters
        text = ""
        alphabet = 0
        shift = False
        
        i = 0
        word_idx = 0
        
        if verbose:
            indent = "  " * depth
                
        while i < len(z_chars):
            # Print verbose info for this word start
            if i % 3 == 0 and verbose and word_idx < len(raw_words):
                w_off, w_val = raw_words[word_idx]
                # Slice next 3 chars/meanings
                word_chars = z_chars[i:i+3]
                word_meanings = meanings[i:i+3]
                
                # Format hex chars
                hex_chars = [f"{c:02X}" for c in word_chars]
                hex_chars_str = "[" + ", ".join(hex_chars) + "]"
                
                meanings_str = ", ".join(word_meanings)
                
                print(f"{indent}@{w_off:04X}: {w_val:04X} -> {hex_chars_str} {meanings_str}")
                word_idx += 1
            
            char = z_chars[i]
            
            # Helper to get char from alphabets
            def map_char(c, alpha):
                if alpha == 0: return self.A0[c-6]
                if alpha == 1: return self.A1[c-6]
                if alpha == 2: return self.A2[c-6]
                return "?"

            # Handle special codes
            if char == 0:
                text += " "
                alphabet = 0 # Shifts reset after a character? No, distinct from lock.
                # Actually, standard V3: Shift (4/5) only applies to NEXT char.
                # But here we are processing a space.
                if shift: 
                    alphabet = 0
                    shift = False
                    
            elif 1 <= char <= 3:
                # Abbreviation
                if i + 1 >= len(z_chars): break # Should not happen in valid string
                
                abbrev_set = char - 1
                abbrev_idx = z_chars[i+1] # Next char is the index
                i += 1 # Consume the index char
                
                # Expand
                text += self.expand_abbreviation(abbrev_set, abbrev_idx, verbose=verbose, depth=depth)
                
                if shift:
                    alphabet = 0
                    shift = False
                    
            elif char == 4:
                alphabet = 1
                shift = True # This is a "Shift", not a "Locks" in V3 typically
            elif char == 5:
                alphabet = 2
                shift = True
            elif char == 6 and alphabet == 2:
                # 10-bit ZSCII literal
                if i + 2 >= len(z_chars): break
                high = z_chars[i+1]
                low = z_chars[i+2]
                zscii_code = (high << 5) | low
                text += chr(zscii_code) # Assuming ASCII subset
                i += 2
                if shift:
                    alphabet = 0
                    shift = False
            else:
                # Normal character
                # The alphabet tables usually start at index 6, so we map char 6 to index 0
                if char >= 6:
                    text += map_char(char, alphabet)
                
                if shift:
                    alphabet = 0 # Reset after one char
                    shift = False
            
            i += 1
            
        return text.replace("\n", "\\n"), byte_len

    def expand_abbreviation(self, set_idx, abbrev_idx, verbose=False, depth=0):
        # Calculate abbreviation address
        # 32 entries per set. Each entry is 2 bytes (word address).
        entry_num = (32 * set_idx) + abbrev_idx
        addr_offset = self.abbrevs_start + (entry_num * 2)
        
        word_addr = struct.unpack(">H", self.data[addr_offset:addr_offset+2])[0]
        # Convert word address to byte address (multiply by 2)
        str_addr = word_addr * 2
        
        if verbose:
            indent = "  " * depth
            print(f"{indent}Abbrev [{set_idx}:{abbrev_idx}] @ {str_addr:04X}")

        # Decode recursively, but we only care about the text, not the length
        text, _ = self.decode(str_addr, verbose=verbose, depth=depth+1)
        return text

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action="store_true", help="Print halfwords and chars")
    args = parser.parse_args()

    try:
        with open("zork1.z3", "rb") as f:
            data = f.read()
    except FileNotFoundError:
        print("Error: zork1.z3 not found.")
        return

    decoder = ZStringDecoder(data)
    
    # Read Object Table address
    obj_table_base = struct.unpack(">H", data[0x0A:0x0C])[0]
    # Skip property defaults
    obj_entries_start = obj_table_base + 62

    print(f"{'Obj':<4} | {'Addr':<6} | {'Len':<4} | {'Abbr?':<5} | {'Content'}")
    print("-" * 60)

    found_with = []
    found_without = []

    for obj_id in range(1, 200):
        entry_addr = obj_entries_start + 9 * (obj_id - 1)
        prop_addr = struct.unpack(">H", data[entry_addr+7 : entry_addr+9])[0]
        text_len_words = data[prop_addr]
        
        if text_len_words > 0:
            str_addr = prop_addr + 1
            
            # Check for abbreviations presence quickly without full decode
            # (Re-using logic from decode or just decoding fully which is safer)
            if args.verbose:
                print(f"String {obj_id} @ {str_addr:04X}:")
            
            text, byte_len = decoder.decode(str_addr, verbose=args.verbose)
            
            if args.verbose:
                print(f"-> \"{text}\"\n")
            
            # Simple check for if an abbreviation expansion happened? 
            # Actually, let's just use my previous logic: check raw chars for 1,2,3
            has_abbrev = False
            # Re-read raw to check for abbrev codes specifically for categorization
            curr = str_addr
            while True:
                w = struct.unpack(">H", data[curr:curr+2])[0]
                chs = decoder.get_z_chars(w)
                if any(c in [1,2,3] for c in chs): has_abbrev = True
                if w & 0x8000: break
                curr += 2

            info = {
                "id": obj_id,
                "addr": str_addr,
                "len": byte_len,
                "abbrev": has_abbrev,
                "text": text
            }
            
            if has_abbrev:
                found_with.append(info)
            else:
                found_without.append(info)

    print("Strings WITHOUT Abbreviations:")
    for item in found_without:
        print(f"{item['id']:<4} | 0x{item['addr']:04X} | {item['len']:<4} | No    | \"{item['text']}\"")

    print("\nStrings WITH Abbreviations:")
    for item in found_with:
        print(f"{item['id']:<4} | 0x{item['addr']:04X} | {item['len']:<4} | YES   | \"{item['text']}\"")

if __name__ == "__main__":
    main()
