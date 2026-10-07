import sys
import re

with open(sys.argv[1], 'r') as f:
    for line in f:
        m = re.match(r'^0x0*([0-9a-fA-F]+):0x0*([0-9a-fA-F]+)', line)
        if m:
            print(f"{m.group(1).upper()}:{m.group(2).upper()}")
