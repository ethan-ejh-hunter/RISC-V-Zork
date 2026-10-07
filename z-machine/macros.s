############################################################################
# 
# Filename: opcodes_utils.s
#
# Author: Ethan Hunter
# Class: ECEN 423, Section 1, Winter 2026
# Date: 1/11/2026
#
# Description: provides utilities for Z-machine opcode implementations. 
#
# macros:
#  Z_POP - pop a value from the Z-machine stack
#  Z_PUSH - push a value onto the Z-machine stack
#
############################################################################# 

.macro Z_POP(%dest_reg)
    # pops a value from the Z-machine stack into dest_reg
    # Z_SP = Z-stack pointer
    lw %dest_reg, 0(Z_SP)      # load value from top of Z-stack
    addi Z_SP, Z_SP, 4          # increment Z-stack pointer
.end_macro

.macro Z_PUSH(%reg)
    addi Z_SP, Z_SP, -4    # Move SP down (toward 0)
    sw   %reg, 0(Z_SP)    # Store value at current SP
    # TODO add overflow check (maybe...)
.end_macro

.macro Z_PACKED_TO_ACTUAL(%packed_reg, %actual_reg, %scratch_reg)
    # converts a packed address (for machine Z3) to an actual address
    # packed address is in %packed_reg
    # actual address is returned in %actual_reg
    slli %actual_reg, %packed_reg, 1   # multiply by 2
    la %scratch_reg, Z_CODE_BASE
    add %actual_reg, %actual_reg, %scratch_reg  # add base address
.end_macro

#Base Address	Row Address	Column Address
#addr[31:14]	addr[13:9]	addr[8:2]

# equation =  
.macro Z_ROW_AND_COL_TO_ADDR(%row_reg, %col_reg, %addr_reg)
    # converts a row and column to a VGA memory address
    # row in %row_reg
    # col in %col_reg
    # address returned in %addr_reg
    li t0, VGA_BASE_ADDR
    slli t1, %row_reg, 9
    slli t2, %col_reg, 2
    add t1, t1, t2
    addi %addr_reg, t1, t0
.end_macro

.macro ZSCII_TO_ASCII(%zscii_char, %alphabet, %scratch_reg)
    # converts a ZSCII character to an ASCII character
    # zscii_char is in %zscii_char (this does get clobbered)
    # alphabet is in %alphabet
    # ascii character is returned in a0
    
    # setup the offset we want into the character table
    mv %scratch_reg, %alphabet
    # shift the alphabet to be in bits 5 and 6
    slli %scratch_reg, %scratch_reg, 5
    # or it into the zscii char
    or %zscii_char, %zscii_char, %scratch_reg
    # now, get the offset into the character table
    la %scratch_reg, ZSCII_CHAR_TABLE
    # get the byte we're talking about...
    add a0, %scratch_reg, %zscii_char
    call READ_BYTE
.end_macro

.macro INGEST_NEXT_BYTE(%scratch_reg)
    # inputs: none
    # outputs: a0 = next byte
    # modifies: Z_PC
    mv a0, Z_PC
    call READ_BYTE
    addi Z_PC, Z_PC, 1
.end_macro

.macro INGEST_NEXT_BE_HALFWORD(%scratch_reg)
    # inputs: none
    # outputs: a0 = next halfword
    # modifies: Z_PC
    mv a0, Z_PC
    call READ_HALFWORD_BE
    addi Z_PC, Z_PC, 2
.end_macro

.macro GET_CHAR(%scratch_base, %scratch_status)
    # returns ascii char in a0
    # li a7, 12
    # ecall
    li %scratch_base, IO_BASE
read_char_loop:
    lw %scratch_status, UART_READ_STATUS_OFFSET(%scratch_base)
    andi %scratch_status, %scratch_status, 0x1
    beq %scratch_status, zero, read_char_loop # wait until new data is available
    # okay, so data is available...
    # read it!
    lw a0, UART_READ_DATA_OFFSET(%scratch_base)
.end_macro

.macro DEBUG_SKIP_IF_DISABLED(%scratch_addr_reg, %scratch_val_reg, %skip_label)
    # Branch to %skip_label when DEBUG_FLAG == 0.
    la %scratch_addr_reg, DEBUG_FLAG
    lw %scratch_val_reg, 0(%scratch_addr_reg)
    beq %scratch_val_reg, zero, %skip_label
.end_macro

.macro DEBUG_7SEG_IMM(%imm)
    li t5, IO_BASE
    li t6, %imm
    sw t6, SEVEN_SEG_OFFSET(t5)
.end_macro

.macro DEBUG_7SEG_REG(%reg)
    li t5, IO_BASE
    sw %reg, SEVEN_SEG_OFFSET(t5)
.end_macro

.macro DEBUG_7SEG_IMM_HOLD(%imm)
    DEBUG_7SEG_IMM(%imm)
    li t3, 1500000
debug_7seg_imm_hold_loop:
    addi t3, t3, -1
    bne t3, zero, debug_7seg_imm_hold_loop
.end_macro

.macro DEBUG_7SEG_REG_HOLD(%reg)
    DEBUG_7SEG_REG(%reg)
    li t3, 1500000
debug_7seg_reg_hold_loop:
    addi t3, t3, -1
    bne t3, zero, debug_7seg_reg_hold_loop
.end_macro
