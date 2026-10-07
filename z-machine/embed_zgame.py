# this was NOT written by me (fully AI, since it's only tooling, and I 
# don't really care enough to write it myself) Not that I couldn't. 
# I fetching love python, I'm just worried about how long I have to finish this
# overall project.
# ALL of the assembly code was written by me.
import re
import os

def main():
    s_file = "z_game.s"
    
    try:
        with open(s_file, "r") as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: {s_file} not found.")
        return

    new_lines = []
    
    incbin_pattern = re.compile(r'^\s*\.incbin\s+"([^"]+)"')
    
    for line in lines:
        match = incbin_pattern.match(line)
        if match:
            bin_file = match.group(1)
            print(f"Found .incbin for '{bin_file}'. Embedding proper bytes...")
            
            try:
                with open(bin_file, "rb") as bf:
                    data = bf.read()
                    
                # Format as .byte 0xXX, 0xXX...
                # We'll do 16 bytes per line
                total_bytes = len(data)
                print(f"Read {total_bytes} bytes from {bin_file}.")
                
                # We can dump huge files, but RARS might choke on 86KB of text lines?
                # Actually 86KB is 86,000 bytes.
                # 16 bytes per line = ~5400 lines. 
                # That should be manageable for RARS, hopefully.
                
                chunk_size = 16
                for i in range(0, total_bytes, chunk_size):
                    chunk = data[i : i + chunk_size]
                    byte_strs = [f"0x{b:02X}" for b in chunk]
                    line_str = "    .byte " + ", ".join(byte_strs) + "\n"
                    new_lines.append(line_str)
                    
            except FileNotFoundError:
                print(f"Error: Binary file '{bin_file}' not found.")
                return
        else:
            new_lines.append(line)
            
    with open(s_file, "w") as f:
        f.writelines(new_lines)
        
    print(f"Successfully updated {s_file}.")

if __name__ == "__main__":
    main()
