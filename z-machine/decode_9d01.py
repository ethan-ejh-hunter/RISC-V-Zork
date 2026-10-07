#!/usr/bin/env python3
# Decode the instruction at 0x9d01 and surrounding opcodes in zork1.z3
# to understand what the 'je' at 9d01 compares

with open('zork1.z3', 'rb') as f:
    mem = f.read()

def get_byte(addr):
    return mem[addr]

def get_word(addr):
    return (mem[addr] << 8) | mem[addr+1]

def decode_operand_type(type_bits):
    if type_bits == 0b00: return 'large_const'
    if type_bits == 0b01: return 'small_const'
    if type_bits == 0b10: return 'variable'
    return 'omitted'

def read_operands_var(pc):
    """Read operand types from a VAR form instruction"""
    types_byte = mem[pc]
    pc += 1
    ops = []
    for i in range(3, -1, -1):
        t = (types_byte >> (i*2)) & 0x3
        if t == 0b11:
            break
        if t == 0b00:
            ops.append(('large', get_word(pc)))
            pc += 2
        elif t == 0b01:
            ops.append(('small', mem[pc]))
            pc += 1
        elif t == 0b10:
            ops.append(('var', mem[pc]))
            pc += 1
    return ops, pc

# Decode from 0x952e (right before 9d01:41 is called) to understand context
# First, check what calls 9d01

# Decode starting at 0x9d01
addr = 0x9d01
opcode_byte = mem[addr]
print(f"0x9d01: opcode byte = 0x{opcode_byte:02x} ({opcode_byte:08b})")

# 0x41 = 0100 0001
# bit7=0: long form
# bit6=1: first operand = variable
# bit5=0: second operand = small constant
# bits4-0 = 0x01 = opcode 1 = je (jump if equal)
bit7 = (opcode_byte >> 7) & 1
bit6 = (opcode_byte >> 6) & 1
bit5 = (opcode_byte >> 5) & 1
opnum = opcode_byte & 0x1f

op_type_map = {0: 'long-form 2OP'}
form = "long form 2OP"
print(f"  Form: {form}, opcode = {opnum}")
print(f"  First operand type: {'variable' if bit6 else 'small const'}")
print(f"  Second operand type: {'variable' if bit5 else 'small const'}")

pc = addr + 1
if bit6:
    op1 = ('var', mem[pc]); pc += 1
else:
    op1 = ('small', mem[pc]); pc += 1

if bit5:
    op2 = ('var', mem[pc]); pc += 1
else:
    op2 = ('small', mem[pc]); pc += 1

print(f"  Operand 1: {op1}")
print(f"  Operand 2: {op2}")

# Read branch
branch_byte = mem[pc]
branch_on_true = (branch_byte >> 7) & 1
short_branch = (branch_byte >> 6) & 1
print(f"  Branch byte: 0x{branch_byte:02x}")
print(f"  Branch on true: {branch_on_true}")

if short_branch:
    offset = branch_byte & 0x3f
    pc += 1
else:
    # 14-bit signed offset
    offset = ((branch_byte & 0x3f) << 8) | mem[pc]
    # sign extend 14-bit
    if offset >= 0x2000:
        offset -= 0x4000
    pc += 2

print(f"  Branch offset: {offset}")
print(f"  After branch decode, PC = 0x{pc:04x}")
if offset == 0:
    print(f"  Branch targets: RFALSE")
elif offset == 1:
    print(f"  Branch targets: RTRUE")
else:
    target = pc + offset - 2
    print(f"  Branch target address: 0x{target:04x}")
print(f"  Next instruction (if not branching): 0x{pc:04x}")
print(f"    opcode at 0x{pc:04x}: 0x{mem[pc]:02x}")
