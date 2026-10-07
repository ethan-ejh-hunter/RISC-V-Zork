############################################################################
# 
# Filename: main.s
#
# Author: Ethan Hunter
# Class: ECEN 423, Section 1, Winter 2026
# Date: 1/11/2026
#
# Description: entry point for the Z-machine emulator
#
# Globals:
# Z-Stack - the Z-machine stack
# ABBREV_TABLE_LOCATION - the address of the abbrev table
# OBJECT_TABLE_LOCATION - the address of the object table
# Functions:
#
############################################################################# 

.data
.align 4

# precalculateded addresses of some different pointers
.globl ABBREV_TABLE_LOCATION
ABBREV_TABLE_LOCATION:
.word 0x00000000
.global PROPERTY_DEFAULTS_TABLE_LOCATION
PROPERTY_DEFAULTS_TABLE_LOCATION:
.word 0x00000000
.globl OBJECT_TABLE_LOCATION
OBJECT_TABLE_LOCATION:
.word 0x00000000
.globl GLOBAL_TABLE_LOCATION
GLOBAL_TABLE_LOCATION:
    .word 0
.global DICTIONARY_LOCATION
DICTIONARY_LOCATION:
    .word 0x00000000
.globl DEBUG_FLAG
DEBUG_FLAG:
    .word 0 # set to 1 to enable debug prints, 0 to disable

# Z-stack frames contain the following: 
# old pc (plus one, so we don't rerun the same "call") (4 bytes)
    # Z_Stack moved to safe location in .data (Allocated via Linker at fixed safe address)
    # 0x10040000 is 192KB past of the start of data (0x10010000). 
    # Z-Machine max memory is 128KB (ends at 0x10030000). 
    # So this is safe.

.data 0x10040000
.align 4
.globl Z_Stack
Z_Stack:
    .space 4096   # 4KB Stack
Z_Stack_Top:
.text
.globl main
main:
    DEBUG_7SEG_IMM_HOLD(0xA010)
    DEBUG_7SEG_REG_HOLD(sp)
    # Ensure native stack pointer is valid before first subroutine call.
    la sp, Z_Stack_Top
    DEBUG_7SEG_REG_HOLD(sp)

    # start by filling in important quick lookup constants
    # first, the location of the abbrev table
    la s1, Z_CODE_BASE
    DEBUG_7SEG_REG_HOLD(s1)
    lw t2, 0(s1)
    DEBUG_7SEG_REG_HOLD(t2)
    addi a0, s1, ABBREV_TABLE_OFFSET
    DEBUG_7SEG_REG_HOLD(a0)
    DEBUG_7SEG_IMM_HOLD(0xA101)
    call READ_HALFWORD_BE
    DEBUG_7SEG_REG_HOLD(a0)
    mv t1, a0 # now, we have the byte address of the abbrev table
    add t1, s1, t1 # add that to the base address of the story
    la t0, ABBREV_TABLE_LOCATION
    sw t1, 0(t0)
    addi a0, s1, OBJECT_TABLE_OFFSET
    call READ_HALFWORD_BE
    mv t1, a0 # now, we have the byte address of the property defaults table
    add t1, s1, t1 # add that to the base address of the story
    la t0, PROPERTY_DEFAULTS_TABLE_LOCATION
    sw t1, 0(t0)
    # the first entry in the objects table is 62 bytes after the property defaults table
    addi t1, t1, PROPERTY_DEFAULTS_TABLE_SIZE
    la t0, OBJECT_TABLE_LOCATION
    sw t1, 0(t0)
    # set the global table location
    addi a0, s1, HEADER_GLOBALS_TABLE_OFFSET
    call READ_HALFWORD_BE
    mv t1, a0 # now, we have the byte address of the global table
    add t1, s1, t1 # add that to the base address of the story
    la t0, GLOBAL_TABLE_LOCATION
    sw t1, 0(t0)
    
    # set the dictionary table location
    addi a0, s1, DICTIONARY_OFFSET
    call READ_HALFWORD_BE
    add t1, s1, a0 # byte address + base address
    la t0, DICTIONARY_LOCATION
    sw t1, 0(t0)
    
    # setup Z-stack pointer
    la Z_FP, Z_Stack_Top
    DEBUG_7SEG_IMM(0xA011)

    # do a ton of setup stuff, probably
    # load the initial PC from the header
    la t0, Z_CODE_BASE
    addi a0, t0, INITIAL_PC_OFFSET
    call READ_HALFWORD_BE
    la t0, Z_CODE_BASE
    add a0, t0, a0 # convert to native address
    addi a0, a0, -1 # Horrible hack... it points to the first opcode, not the header
    # but the byte before the first opcode is in fact 0x00... so subtract one and we're fine. 
    mv Z_PC, a0       # Z_PC = Z-PC (save it just in case we need it?)
    DEBUG_7SEG_IMM(0xA012)
    
    li a1, -1      # a1 is the return location for the initial call (no return)
    li a2, 0       # no arguments to initial call
    DEBUG_7SEG_IMM(0xA013)
    call DO_CALL   # call the initial routine
    DEBUG_7SEG_IMM(0xA014)
    j EXECUTE_OPCODE
    # now just loop forever (we should never return here)
.globl QUIT
QUIT:
    DEBUG_7SEG_IMM(0xA0FF)
    j QUIT


    
