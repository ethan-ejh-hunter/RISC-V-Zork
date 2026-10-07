############################################################################
# 
# Filename: constants.s
#
# Author: Ethan Hunter
# Class: ECEN 423, Section 1, Winter 2026
# Date: 1/11/2026 
#
# Description: global constants for the Z-machine emulator 
#
# constants:
# 
#
############################################################################# 

# TODO : set to actual address of globals table in memory
.eqv GLOBALS_TABLE_POINTER 0xffff
# base address of VGA text mode memory
.eqv VGA_BASE_ADDR 0x00008000
.eqv LAST_5_BITS 0x1F
.eqv ALL_BUT_LAST_BIT -2
.eqv MSB_TWO_BITS 0xc0 


.eqv IO_BASE 0x00007f00
.eqv LED_OFFSET 0x00
.eqv SWITCH_OFFSET 0x04
.eqv UART_TX_OFFSET 0x08
.eqv UART_READ_DATA_OFFSET 0x10
.eqv UART_READ_STATUS_OFFSET 0x14
.eqv SEVEN_SEG_OFFSET 0x18
.eqv BUTTON_OFFSET 0x24
.eqv TIMER_OFFSET 0x30


# -----------------------------------------------------------------------------
# Character Constants
# -----------------------------------------------------------------------------
.eqv SPACE 0x20
.eqv NEWLINE_CHAR 0x0A


# -----------------------------------------------------------------------------
# Register Aliases
# -----------------------------------------------------------------------------
# Z-Machine Stack Pointer
.eqv Z_SP s9
# Z-Machine Stack Frame Pointer (Floor)
.eqv Z_FP s10
# Z-Machine Program Counter
.eqv Z_PC s11

# -----------------------------------------------------------------------------
# Opcode Parsing Constants
# -----------------------------------------------------------------------------
.eqv FORM_MASK 0xc0
.eqv FORM_SHORT 0x40
.eqv FORM_2OP 0xc0

.eqv SHORT_FORM_OPCODE_MASK 0x0f
.eqv SHORT_FORM_OPERAND_TYPE_MASK 0x30
.eqv VAR_FORM_OPCODE_MASK 0x1f # bottom 5 bits
.eqv VAR_OR_2OP_OPCODE_MASK 0x20
.eqv LONG_FORM_CHECK 0x80

.eqv LONG_FORM_OPCODE_MASK 0x1f

# short form operand lookup
.eqv SHORT_FORM_NO_OPERANDS 0x30
.eqv SHORT_FORM_VARIABLE 0x20
.eqv SHORT_FORM_SMALL_CONSTANT 0x01
.eqv SHORT_FORM_LARGE_CONSTANT 0x00


# Single bit bitmasks...
.eqv MSB_BIT 0x80
.eqv MSB_BIT_2 0x40
.eqv MSB_BIT_3 0x20
.eqv MSB_BIT_4 0x10
.eqv MSB_BIT_5 0x08
.eqv MSB_BIT_6 0x04
.eqv MSB_BIT_7 0x02
.eqv MSB_BIT_8 0x01


# -----------------------------------------------------------------------------
# Header Offsets
# -----------------------------------------------------------------------------
# address of the start of the Z-machine header
.eqv HEADER_ADDRESS z_header
# offset of the initial PC in the header
.eqv INITIAL_PC_OFFSET 0x06
# offset of the dictionary address in the header
.eqv DICTIONARY_OFFSET 0x08
# offset of the object table address in
.eqv OBJECT_TABLE_OFFSET 0x0A
# offset of the globals table address in the header
.eqv HEADER_GLOBALS_TABLE_OFFSET 0x0C
# offset of the static memory address in
.eqv STATIC_MEM_OFFSET 0x0E
# offset of the abbreviation table address in the header
.eqv ABBREV_TABLE_OFFSET 0x18
# size of property defaults table
.eqv PROPERTY_DEFAULTS_TABLE_SIZE 62

.eqv PARENT_OFFSET 0x04
.eqv SIBLING_OFFSET 0x05
.eqv CHILD_OFFSET 0x06
