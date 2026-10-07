import sys
import re
import os

def load_disassembly(filename):
    disasm = {}
    if not os.path.exists(filename):
        print(f"Warning: Disassembly file {filename} not found.")
        return disasm
        
    # Pattern to match "  5049: loadw            L00 #00 -> L01 "
    # Address is usually 4+ hex digits followed by a colon
    pattern = re.compile(r'^\s*([0-9a-fA-F]+):\s*(.*)$')
    
    with open(filename, 'r') as f:
        for line in f:
            match = pattern.match(line)
            if match:
                addr = match.group(1).upper()
                instr = match.group(2).strip()
                disasm[addr] = instr
    return disasm

def extract_trace_info(filename, is_rars):
    trace_info = []
    # Pattern to match "XXXX:XX [arg1, arg2, ...]"
    # RARS offset: 0x0000XXXX:0x000000XX [0x..., 0x...]
    # Zorkmid: XXXX:XX [XXXX, XXXX, ...]
    
    with open(filename, 'r') as f:
        for line in f:
            if is_rars:
                match = re.search(r'0x0*([0-9a-fA-F]+):0x0*([0-9a-fA-F]+)\s*\[(.*?)\]', line)
            else:
                if ">" in line:
                    # this means, we want to cut all characters up until the last ">"
                    line = line.split(">")[-1]
                    print(line)
                    # now, we have a weird line that looks like "<68039 68042 140 1 -184 0 -2 110910:0a [00a4, 0007]"
                    # we want to extract 
                # Zorkmid trace often has the PC:OP at the start of the line or in stderr mix
                match = re.search(r'([0-9a-fA-F]+):([0-9a-fA-F]+)\s*\[(.*?)\]', line)
            
            if match:
                pc = match.group(1).upper()
                args_str = match.group(3)
                # Clean up RARS hex format (0xXXXX) and normalize to 16-bit (4 hex digits)
                args = [a.strip().replace('0x', '').upper()[-4:].zfill(4) for a in args_str.split(',') if a.strip()]
                trace_info.append({'pc': pc, 'args': args, 'line': line.strip()})
    return trace_info

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <zorkmid_trace> <rars_trace> [disassembly_file]")
        sys.exit(1)
        
    zorkmid_trace = extract_trace_info(sys.argv[1], False)
    rars_trace = extract_trace_info(sys.argv[2], True)
    
    disasm_file = sys.argv[3] if len(sys.argv) > 3 else "z-disassemble-simple.txt"
    disasm = load_disassembly(disasm_file)
    
    i, j = 0, 0
    divergence = -1
    reason = ""
    
    while i < len(zorkmid_trace) and j < len(rars_trace):
        z_pc = zorkmid_trace[i]['pc']
        r_pc = rars_trace[j]['pc']
        
        if z_pc == r_pc:
            # Check arguments
            z_args = zorkmid_trace[i]['args']
            r_args = rars_trace[j]['args']
            if z_args != r_args and z_pc not in ("6050", "6061", "603F", "607F", "6083", "602D", "6036"):
                divergence = i
                reason = f"Argument mismatch at PC {z_pc}: Zorkmid {z_args} vs RARS {r_args}"
                break
            i += 1
            j += 1
        else:
            if j+1 < len(rars_trace) and z_pc == rars_trace[j+1]['pc']:
                print(f"Zorkmid skipped/buffered RARS PC: {rars_trace[j]['pc']}")
                j += 1
            elif i+1 < len(zorkmid_trace) and zorkmid_trace[i+1]['pc'] == r_pc:
                print(f"RARS skipped Zorkmid PC: {z_pc}")
                i += 1
            else:
                divergence = i
                reason = f"PC mismatch: Zorkmid {z_pc} vs RARS {r_pc}"
                break
                
    if divergence != -1:
        print(f"Real divergence found at Zorkmid step {i+1}, RARS step {j+1}:")
        print(f"Reason: {reason}")
        
        z_info = zorkmid_trace[i]
        r_info = rars_trace[j]
        
        z_instr = disasm.get(z_info['pc'], "???")
        r_instr = disasm.get(r_info['pc'], "???")
        
        print(f"  Zorkmid: {z_info['pc']} | {z_instr} | Args: {z_info['args']}")
        print(f"     RARS: {r_info['pc']} | {r_instr} | Args: {r_info['args']}")
        
        start_i = max(0, i - 10)
        start_j = max(0, j - 10)
        end_i = min(len(zorkmid_trace), i + 10)
        end_j = min(len(rars_trace), j + 10)
        
        print("\nZorkmid Context:")
        for idx in range(start_i, end_i):
            marker = "->" if idx == i else "  "
            pc = zorkmid_trace[idx]['pc']
            instr = disasm.get(pc, "")
            args = zorkmid_trace[idx]['args']
            print(f"{marker} {idx+1:4} | {pc:4} | {instr} | {args}")
            
        print("\nRARS Context:")
        for idx in range(start_j, end_j):
            marker = "->" if idx == j else "  "
            pc = rars_trace[idx]['pc']
            instr = disasm.get(pc, "")
            args = rars_trace[idx]['args']
            print(f"{marker} {idx+1:4} | {pc:4} | {instr} | {args}")
        sys.exit(1)
        
    print("Files match after allowing for skips!")

if __name__ == "__main__":
    main()
