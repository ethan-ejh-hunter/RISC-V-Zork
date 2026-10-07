############################################################################
# 
# Filename: opcodes.s
#
# Author: Ethan Hunter
# Class: ECEN 423, Section 1, Winter 2026
# Date: 1/11/2026
#
# Description: provides implementations of Z-machine opcodes. The only routine you should call
#              from outside this file is execute_opcode, which takes care of dispatching to the
#              appropriate opcode handler.
#
# routines (that you should touch, dummy): 
#   EXECUTE_OPCODE - main opcode dispatcher
#
############################################################################# 

# Z-stack frames contain the following: 
# old pc (plus one, so we don't rerun the same "call") (4 bytes)
# old stack frame pointer (4 bytes)
# where to store the return value (4 bytes)
# local variables (16 * 2 bytes = 32 bytes) <= stack floor is on the last word of this
# here's where the routine sees the stack (it pushes/pops from)

.data
eol_str:			# End of line
	.asciz "\n"
exec_str:
    .asciz "EXEC\n"
debug_ctr:
    .word 0
l02_str:
    .asciz " L02: "
l03_str:
    .asciz " L03: "
RNG_STATE:
    .word 0x0000ACE1

.align 4
num_0_op_opcode_table:
    .word op_0OP_return_true        # opcode 0x00
    .word op_0OP_return_false       # opcode 0x01
    .word op_0OP_print            # opcode 0x02
    .word op_0OP_print_ret        # opcode 0x03
    .word op_0OP_nop
    .word op_0OP_nop            # this is technically the "save" opcode, but we don't implement it
    .word op_0OP_nop        # opcode 0x06, unimplemented restore
    .word op_0OP_nop           # opcode 0x07, restart
    .word op_0OP_ret_popped       # opcode 0x08
    .word op_0OP_pop
    .word op_0OP_quit           # opcode 0x0A, quit
    .word op_0OP_newline           # TODO opcode 0x0B, new_line
    .word op_0OP_showstatus           # TODO opcode 0x0C, show_status
    .word op_0OP_verify           # TODO opcode 0x0D, verify... idk
    .word op_0OP_nop           # opcode 0x0E, 
    .word op_0OP_nop           # opcode 0x0F, 
num_1_op_opcode_table:
    .word op_1OP_jz          # TODO, opcode 0x00, jump if arg is 0
    .word op_1OP_get_sibling     # TODO, opcode 0x01, get_sibling
    .word op_1OP_get_child        # TODO, opcode 0x02, get_child
    .word op_1OP_get_parent       # TODO, opcode 0x03, get_parent
    .word op_1OP_get_prop_len     # TODO, opcode 0x04, get_prop_len
    .word op_1OP_inc             # TODO, opcode 0x05, inc'
    .word op_1OP_dec             # TODO, opcode 0x06, dec'
    .word op_1OP_print_addr      # TODO, opcode 0x07, print_addr
    .word op_UNK_PANIC      # opcode 0x08, unassigned (panic)
    .word op_1OP_remove_obj       # TODO, opcode 0x09, remove_obj
    .word op_1OP_print_obj        # TODO, opcode 0x0A, print_obj
    .word op_1OP_ret_value        # opcode 0x0B, return
    .word op_1OP_jump             # TODO, opcode 0x0C, jump
    .word op_1OP_print_paddr      # TODO, opcode 0x0D, print_paddr
    .word op_1OP_load             # TODO, opcode 0x0E, load
    .word op_1OP_not             # TODO, opcode 0x0F, not
num_2_op_opcode_table:
    .word op_UNK_PANIC           # op 0x00 is undefined, best I can tell...
    .word op_2OP_jeq            # TODO, opcode 0x01, jump if args are equal
    .word op_2OP_jl          # TODO, opcode 0x02, jump if arg 1 is less than arg 2
    .word op_2OP_jg          # TODO, opcode 0x03, jump if arg 1 is greater than arg 2
    .word op_2OP_dec_chk     # TODO, opcode 0x04, decrement arg 1 and jump if it's less than arg 2
    .word op_2OP_inc_chk     # TODO, opcode 0x05, increment arg 1 and jump if it's greater than arg 2
    .word op_2OP_jin     # TODO, opcode 0x06, jump if arg 1 is in arg 2
    .word op_2OP_test     # TODO, opcode 0x07, jump if all flags in bitmap are set
    .word op_2OP_or         # TODO, opcode 0x08
    .word op_2OP_and# TODO, opcode 0x09
    .word op_2OP_testattr # TODO, opcode 0x0A
    .word op_2OP_setattr # TODO, opcode 0x0B
    .word op_2OP_clear_attr # TODO, opcode 0x0C
    .word op_2OP_store # TODO, opcode 0x0D
    .word op_2OP_insert_obj # TODO, opcode 0x0E
    .word op_2OP_loadw # TODO, opcode 0x0F
    .word op_2OP_loadb # TODO, opcode 0x10
    .word op_2OP_get_prop # TODO, opcode 0x11
    .word op_2OP_get_prop_addr # TODO, opcode 0x12
    .word op_2OP_get_next_prop # TODO, opcode 0x13
    .word op_2OP_add # TODO, opcode 0x14
    .word op_2OP_sub # TODO, opcode 0x15
    .word op_2OP_mul # TODO, opcode 0x16
    .word op_2OP_div # TODO, opcode 0x17
    .word op_2OP_mod # TODO, opcode 0x18

var_form_opcode_table:
    .word op_VAR_call             # op 0x00
    .word op_VAR_storew           # op 0x01
    .word op_VAR_storeb           # op 0x02
    .word op_VAR_put_prop         # op 0x03
    .word op_VAR_sread            # op 0x04
    .word op_VAR_print_char       # op 0x05
    .word op_VAR_print_num        # op 0x06
    .word op_VAR_random           # op 0x07
    .word op_VAR_push             # op 0x08
    .word op_VAR_pull             # op 0x09
    .word op_VAR_split_window     # op 0x0A, unused, just ebrea
    .word op_VAR_set_window       # op 0x0B
    .word op_UNK_PANIC          # op 0x0C, undefined
    .word op_UNK_PANIC          # op 0x0D, undefined
    .word op_UNK_PANIC          # op 0x0E, undefined
    .word op_UNK_PANIC          # op 0x0F, undefined 
    .word op_UNK_PANIC          # op 0x10, undefined
    .word op_UNK_PANIC          # op 0x11, undefined
    .word op_UNK_PANIC          # op 0x12, undefined
    .word op_output_stream          # op 0x13, output_stream
    .word op_input_stream          # op 0x14, input_stream
    .word op_UNK_PANIC          # op 0x15, undefined
    .word op_UNK_PANIC          # op 0x16, undefined
    .word op_UNK_PANIC          # op 0x17, undefined
    .word op_UNK_PANIC          # op 0x18, undefined
    .word op_UNK_PANIC          # op 0x19, undefined
    .word op_UNK_PANIC          # op 0x1A, undefined
    .word op_UNK_PANIC          # op 0x1B, undefined
    .word op_UNK_PANIC          # op 0x1C, undefined
    .word op_UNK_PANIC          # op 0x1D, undefined
    .word op_UNK_PANIC          # op 0x1E, undefined
    .word op_UNK_PANIC          # op 0x1F, undefined
.text



# Main opcode execution routine
.globl EXECUTE_OPCODE
# No arguments; uses global state for PC, memory, etc.
# but Z_PC is the Z-machine PC
# Z_FP is the Z-machine stack frame floor
# Z_SP is the Z-machine stack pointer
# a0-a6 are used for operand passing to opcode handlers
EXECUTE_OPCODE:
    # save return address and s1, s2
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)
    DEBUG_7SEG_IMM(0xB000)

    # Opcode dispatching logic goes here
    # Overall steps we need to do: 
    # First, fetch the opcode from memory at the current PC.
    # Decide what the "form" of the opcode is (0OP, 1OP, 2OP, VAR).
    # Based on the form, decode the operands, and store them in a0-a6 as needed.
opcode_dispatch_loop:
    # --- TRACE: print 0xPC:0xOPCODE ---
    DEBUG_SKIP_IF_DISABLED(t3, t4, trace_pc_prefix_done)
    mv a0, Z_PC
    la t0, Z_CODE_BASE
    sub a0, a0, t0      # a0 = Z-machine PC offset
    li a7, 34           # print hex
    ecall
    li a0, ':'
    li a7, 11
    ecall
trace_pc_prefix_done:
    # ---
    

    INGEST_NEXT_BYTE(a0)
    mv s1, a0           # save the opcode in s1
    andi t0, s1, 0x00FF
    li t1, 0xB100
    add t0, t0, t1
    DEBUG_7SEG_REG(t0)

    DEBUG_SKIP_IF_DISABLED(t3, t4, trace_opcode_done)
    mv a0, s1
    li a7, 34           # print opcode byte as hex
    ecall
trace_opcode_done:
    
    # We will print the arguments later [arg1, arg2, ...]
    # ---

    mv a0, s1
    # a0 now has the opcode byte
    # is it long form?
    andi t0, a0, LONG_FORM_CHECK
    # if that's a zero, it's long form
    beq t0, zero, long_form
    andi t0, a0, FORM_SHORT
    beq t0, zero, short_form

    # var form and 2 op are the same, except that 2op is 
    # bound by the spec to have the last 4 bits of type byte be
    # 0b1111 (both omitted)
    # but the operands are in var form...
    # So we can reuse the variable form operand parsing logic
    # and the opcode mask for 2op (just switch the offset to use the 2op table)

    # get and save the opcode num...
    andi s2, s1, VAR_FORM_OPCODE_MASK
    call GET_VARIABLE_OPERANDS
    # the operands are in a0-a3, count is in a4
    
    # print operands for trace
    # save a0-a4
    addi sp, sp, -24
    sw a0, 0(sp)
    sw a1, 4(sp)
    sw a2, 8(sp)
    sw a3, 12(sp)
    sw a4, 16(sp)
    sw ra, 20(sp)
    call PRINT_OPERANDS
    lw a0, 0(sp)
    lw a1, 4(sp)
    lw a2, 8(sp)
    lw a3, 12(sp)
    lw a4, 16(sp)
    lw ra, 20(sp)
    addi sp, sp, 24
    
    # so it's either var form or 2op
    andi t0, s1, VAR_OR_2OP_OPCODE_MASK
    # if the bit is 1, then var form
    bne t0, zero, var_form
    # otherwise, it's 2op
    la t1, num_2_op_opcode_table
    j jump_to_opcode

var_form:
    # now that we have the operands, just jump to the correct opcode
    la t1, var_form_opcode_table
    j jump_to_opcode

short_form:
    # it's short form, so we need to get the opcode
    andi s2, a0, SHORT_FORM_OPCODE_MASK
    # get the operand type bits
    andi t2, a0, SHORT_FORM_OPERAND_TYPE_MASK
    # is it 0OP?
    li t3, SHORT_FORM_NO_OPERANDS
    beq t2, t3, zero_op
one_op:
    call GET_SHORT_OPERAND
    # a0 has the operand, a4 = 1
    li a4, 1
    
    # print operands for trace
    addi sp, sp, -12
    sw a0, 0(sp)
    sw a4, 4(sp)
    sw ra, 8(sp)
    call PRINT_OPERANDS
    lw a0, 0(sp)
    lw a4, 4(sp)
    lw ra, 8(sp)
    addi sp, sp, 12
    
    la t1, num_1_op_opcode_table
    j jump_to_opcode
    
zero_op:
    # 0OP has 0 operands
    li a4, 0
    # print operands for trace
    addi sp, sp, -8
    sw a4, 0(sp)
    sw ra, 4(sp)
    call PRINT_OPERANDS
    lw a4, 0(sp)
    lw ra, 4(sp)
    addi sp, sp, 8
    
    la t1, num_0_op_opcode_table
    j jump_to_opcode

long_form:
    call GET_LONG_OPERANDS
    # the operands are in a0 and a1, a4 = 2 (implied)
    li a4, 2
    
    # print operands for trace
    addi sp, sp, -16
    sw a0, 0(sp)
    sw a1, 4(sp)
    sw a4, 8(sp)
    sw ra, 12(sp)
    call PRINT_OPERANDS
    lw a0, 0(sp)
    lw a1, 4(sp)
    lw a4, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    
    # get the opcode...
    andi s2, s1, LONG_FORM_OPCODE_MASK
    la t1, num_2_op_opcode_table
    j jump_to_opcode

jump_to_opcode:
    #this expects the opcode number in s2, 
    # and the table base address in t1
    # get the opcode handler
    slli t0, s2, 2 # multiply the opcode by 4 to get the offset into the table
    add t1, t1, t0
    lw t1, 0(t1)
    jalr ra, t1, 0
    # we got returned from the opcode handler
    # restore the actual return address and return
    j opcode_dispatch_loop

# Helper to print operands in trace: [arg1, arg2, ...]
# a0-a3: operands, a4: count
PRINT_OPERANDS:
    DEBUG_SKIP_IF_DISABLED(t5, t6, print_operands_skip)

    addi sp, sp, -28
    sw ra, 24(sp)
    sw s0, 20(sp) # count
    sw s1, 16(sp) # index
    sw a0, 0(sp)
    sw a1, 4(sp)
    sw a2, 8(sp)
    sw a3, 12(sp)

    mv s0, a4
    
    li a0, ' '
    li a7, 11
    ecall
    li a0, '['
    li a7, 11
    ecall

    li s1, 0
print_op_loop:
    beq s1, s0, print_op_done
    
    # get operand address
    slli t0, s1, 2
    add t0, sp, t0
    lw a0, 0(t0)
    
    # zero extend to 16 bits for display
    slli a0, a0, 16
    srli a0, a0, 16
    
    # print as hex
    # RARS doesn't have a direct %04x # ecall easily, but li a7, 34 prints as 0x...
    # we want regular hex if possible. let's use 34 for now or 1 for dec?
    # user_information says linux, RARS is RISC-V.
    # zorkmid uses %04x. 
    li a7, 34 # print hex
    ecall
    
    addi s1, s1, 1
    beq s1, s0, print_op_done
    
    li a0, ','
    li a7, 11
    ecall
    li a0, ' '
    li a7, 11
    ecall
    j print_op_loop

print_op_done:
    li a0, ']'
    li a7, 11
    ecall
    li a0, '\n'
    li a7, 11
    ecall
    
    lw ra, 24(sp)
    lw s0, 20(sp)
    lw s1, 16(sp)
    addi sp, sp, 28
    ret

print_operands_skip:
    ret

op_0OP_pop:
    Z_POP(x0) # pop and throw away
    ret

op_0OP_quit:
    j QUIT

op_0OP_nop:
    # do nothing
    ret
# these next several opcodes all share some code, for space
# s1 is used as the value to return
op_0OP_print_ret:
    li s1, 1
    # set a flag locally in t6 telling the print handler to jump to ret handler
    li s2, 1
    j op_0OP_print_shared
op_0OP_print:
    li s2, 0
op_0OP_print_shared:
    addi sp, sp, -4
    sw ra, 0(sp)
    # ebreak
    mv a0, Z_PC # don't increment, since INGEST_NEXT_BYTE increments
    call PRINT_ZSCII_STRING
    # a0 has the address of the next char. 
    mv Z_PC, a0
    # restore ra before branching or returning
    lw ra, 0(sp)
    addi sp, sp, 4
    bne s2, x0, do_return 
    ret
op_0OP_ret_popped:
    # pop a value from the Z-machine stack into s1
    Z_POP(s1)
    j do_return
op_0OP_return_true:
    # load true into s1
    li s1, 1
    j do_return
op_0OP_return_false:
    # load false into s1
    li s1, 0
do_return:
    # save return pointer
    addi sp, sp, -4
    sw ra, 0(sp)
    mv a0, s1        # a0 = return value
    call DO_RETURN
    lw ra, 0(sp)        # restore actual return address
    addi sp, sp, 4
    ret
op_1OP_ret_value:
    # the return value is already in a0
    j DO_RETURN
op_0OP_newline:
    # jump to the newline handler
    j NEWLINE

# Stubs for unimplemented opcodes
op_0OP_showstatus:
    ebreak
    ret
op_0OP_verify:
    ebreak
    ret
op_1OP_jz:
    # jump if a0 is zero

    slt t0, a0, x0
    slt t1, x0, a0
    or t0, t0, t1 # t0 = 1 if a0 != 0, else 0
    xori a0, t0, 1 # a0 = 1 if a0 was originally 0, else 0
    j DO_BRANCH
    ret
op_1OP_get_sibling:
    # get_child object → (result)?(label)
    # we just assume it isn't 0... since undefined behavior if it is
    # save the object number
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s1, 4(sp)
    call GET_OBJECT_ADDRESS
    # the address is already in a0
    li a1, SIBLING_OFFSET
    call GET_OBJECT_RELATION
    mv s1, a0
    # a0 has the relation value. Jump to store it and consume the store byte
    call DO_STORE_FROM_BYTE
    slti a0, s1, 1 # relation val < 1 (i.e. 0) -> 1, else 0
    # invert the result (so if the relation is 0, it becomes 0, all other cases
    # it becomes 1)
    xori a0, a0, 1
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 8
    # now we can just jump to the branch handler
    j DO_BRANCH
    ret
op_1OP_get_child:
    # get_child object → (result)?(label)
    # we just assume it isn't 0... since undefined behavior if it is
    # save the object number
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s1, 4(sp)
    call GET_OBJECT_ADDRESS
    # the address is already in a0
    li a1, CHILD_OFFSET
    call GET_OBJECT_RELATION
    mv s1, a0
    # a0 has the relation value. Jump to store it and consume the store byte
    call DO_STORE_FROM_BYTE
    slti a0, s1, 1 # relation val < 1 (i.e. 0) -> 1, else 0
    # invert the result (so if the relation is 0, it becomes 0, all other cases
    # it becomes 1)
    xori a0, a0, 1
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 8
    # now we can just jump to the branch handler
    j DO_BRANCH
    ret
op_1OP_get_parent:
    # a0 = object number, a1 = parent object number
    addi sp, sp, -16
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
    mv s0, a1
    mv s1, a2

    call GET_OBJECT_ADDRESS
    # the address is already in a0
    li a1, PARENT_OFFSET
    call GET_OBJECT_RELATION
    
    # restore s-registers and ra
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    addi sp, sp, 16

    # a0 has the relation value. Jump to store it and consume the store byte
    j DO_STORE_FROM_BYTE
    ret
op_1OP_get_prop_len:
    # a0: pointer to (in z-mem) the byte after the size byte
    addi sp, sp, -4
    sw ra, 0(sp)
    beq a0, x0, prop_len_not_found
    addi a0, a0, -1
    la t0, Z_CODE_BASE
    add a0, a0, t0
    call READ_BYTE
    # now we have the size byte... so pull out the size part. 
    andi a0, a0, 0xE0
    # shift it down
    srli a0, a0, 5
    addi a0, a0, 1
    lw ra, 0(sp)
    addi sp, sp, 4
    j DO_STORE_FROM_BYTE
prop_len_not_found:
    li a0, 0
    lw ra, 0(sp)
    addi sp, sp, 4
    j DO_STORE_FROM_BYTE
    ret
op_1OP_inc:
    # inc (variable)
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s1, 4(sp)
    mv s1, a0
    call DO_READ
    addi a1, a0, 1
    mv a0, s1
    call DO_WRITE
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 8
    ret
op_1OP_dec:
    # dec (variable)
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s1, 4(sp)
    mv s1, a0
    call DO_READ
    addi a1, a0, -1
    mv a0, s1
    call DO_WRITE
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 8
    ret
op_1OP_print_addr:  
    # a0 = byte address
    # convert to actual address
    addi sp, sp, -4
    sw ra, 0(sp)
    # Operand values are 16-bit unsigned addresses.
    # Clear sign-extended upper bits before address arithmetic.
    slli a0, a0, 16
    srli a0, a0, 16
    la t0, Z_CODE_BASE
    add a0, a0, t0
    # print the string at that address
    call PRINT_ZSCII_STRING
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_UNK_PANIC:
    DEBUG_7SEG_IMM(0xDEAD)
    ebreak
    ret
op_1OP_remove_obj:
    # a0 = object number to remove from its parent
    addi sp, sp, -4
    sw ra, 0(sp)
    call REMOVE_OBJECT_FROM_TREE
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_1OP_print_obj:
    # a0 = object number
    # print the object's name
    addi sp, sp, -4
    sw ra, 0(sp)
    
    call GET_OBJECT_ADDRESS
    # the address is already in a0
    call GET_OBJECT_PROPERTY_ADDRESS
    # a0 now holds address of property table
    # the first byte is the text length in words (which we skip)
    addi a0, a0, 1
    # compressed zchar string starts after the length byte. 
    call PRINT_ZSCII_STRING
    # ebreak
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_1OP_jump:
    # the branch logic is still current Z_PC - 2 + offset
    # even though you can't do the funky return. Who knows why lol
    addi Z_PC, Z_PC, -2
    add Z_PC, Z_PC, a0
    ret
op_1OP_print_paddr:
    # a0 = packed address
    # convert to actual address
    addi sp, sp, -4
    sw ra, 0(sp)
    # Packed addresses are 16-bit unsigned values... so clear sign bits. 
    slli a0, a0, 16
    srli a0, a0, 15
    la t0, Z_CODE_BASE
    add a0, a0, t0
    # print the string at that address
    call PRINT_ZSCII_STRING
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_1OP_load:
    # a0 = variable number whose value should be pushed to store
    # read from that variable, then store the result
    addi sp, sp, -4
    sw ra, 0(sp)
    call DO_READ
    # a0 now has the value; pass to DO_STORE_FROM_BYTE
    call DO_STORE_FROM_BYTE
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_1OP_not:
    # a0 = variable number to read, negate, and store
    addi sp, sp, -4
    sw ra, 0(sp)
    call DO_READ
    # a0 now has the value:  not and pass to DO_STORE_FROM_BYTE
    li t0, 0xffff
    and a0, a0, t0 # Z-machine spec says to only consider the low bit for not
    not a0, a0
    call DO_STORE_FROM_BYTE
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

op_VAR_call:
    # a0 (routine), a1-a3 (args), a4 (count)
    
    # Save operands to stack to preserve across READ_BYTE
    addi sp, sp, -24
    sw ra, 20(sp)
    sw a4, 0(sp) # count
    sw a0, 4(sp) # routine to call
    sw a1, 8(sp) # arg1 (Op 2)
    sw a2, 12(sp) # arg2 (Op 3)
    sw a3, 16(sp) # arg3 (Op 4)
    
    # get the variable number to write the return value to
    mv a0, Z_PC
    call READ_BYTE
    mv a1, a0
    addi Z_PC, Z_PC, 1 # increment past the variable number
    
    
    # Restore and map for DO_CALL
    # DO_CALL(a0=routine, a1=retvar, a2=num_args, a3=arg1...)
    # a1 is already set (return var)
    
    lw t0, 0(sp) # count (Num Ops)
    addi a2, t0, -1 # Num Args = Ops - 1 (routine is op1)
    
    lw a0, 4(sp) # Routine (packed)

    # DO_READ sign-extends 16-bit values; routine addresses are unsigned packed
    # addresses. Clear upper bits so 0x8481 does not become 0xFFFF8481.
    slli a0, a0, 16
    srli a0, a0, 16

    # Check if routine address is 0 (spec says to just return false)
    beq a0, zero, call_routine_zero

    # Convert packed address to actual address
    # actual = (packed * 2) + Z_CODE_BASE
    slli a0, a0, 1
    la t0, Z_CODE_BASE
    add a0, a0, t0
    
    lw a3, 8(sp) # Arg1
    lw a4, 12(sp) # Arg2
    lw a5, 16(sp) # Arg3
    
    call DO_CALL
    lw ra, 20(sp)
    addi sp, sp, 24
    ret

call_routine_zero:
    # return false (0)
    # The return variable is currently in a1.
    mv a0, a1 # move variable number to a0 for DO_WRITE
    li a1, 0  # value to write is 0
    call DO_WRITE
    lw ra, 20(sp)
    addi sp, sp, 24
    ret
op_VAR_storew:
    # a0 = array address
    # a1 = word index
    # a2 = value
    # save the original RA
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # zero extend array and index
    slli a0, a0, 16
    srli a0, a0, 16
    slli a1, a1, 16
    srli a1, a1, 16

    la t0, Z_CODE_BASE
    add a0, a0, t0         # add to base address
    slli a1, a1, 1         # multiply index by 2
    add a0, a0, a1         # a0 is now the final address
    
    mv a1, a2              # move value to a1 for WRITE_HALFWORD_BE
    
    call WRITE_HALFWORD_BE

    # restore RA
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

op_VAR_storeb:
    # a0 = array address
    # a1 = byte index
    # a2 = value
    addi sp, sp, -4
    sw ra, 0(sp)
    # zero extend array and index
    slli a0, a0, 16
    srli a0, a0, 16
    slli a1, a1, 16
    srli a1, a1, 16

    la t0, Z_CODE_BASE
    add a0, a0, t0         # add to base address
    add a0, a0, a1         # a0 is now the final address
    mv a1, a2              # move value to a1 for WRITE_BYTE
    call WRITE_BYTE
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_VAR_put_prop:
    # the args are in a0-a2
    # a4 is number of args we have
    # a0 should be the object num
    # a1 is property num
    # a2 is the value
    # save s1-s3 on stack and ra
    addi sp, sp, -24
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)

    mv s1, a0 # object number
    mv s2, a1 # property number
    mv s3, a2 # value
    mv a0, s1
    call GET_OBJECT_ADDRESS
    # the address is already in a0
    mv a1, s2 # property number
    mv a2, s3 # value
    call SET_OBJECT_PROPERTY

    # restore s1-s3 and ra
    lw s3, 12(sp)
    lw s2, 8(sp)
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 24
    ret
op_VAR_sread:
    # a0 = text buffer pointer
    # a1 = parse buffer pointer
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    # zero extend to ensure they are treated as unsigned offsets
    slli a0, a0, 16
    srli a0, a0, 16
    slli a1, a1, 16
    srli a1, a1, 16

    la t0, Z_CODE_BASE
    add s0, a0, t0
    add s1, a1, t0
    # ebreak


    mv a0, s0 # text buffer pointer
    mv a1, s1 # parse buffer pointer
    call GET_LINE_TO_ZCHAR_BUFFER
    
    # now, the text is in a0... We should be able to just call parse_line
    # PARSE_ASCII_STRING expects the text buffer in a0 and the parse buffer in a1
    mv a0, s0
    mv a1, s1
    call PARSE_ASCII_STRING

    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    addi sp, sp, 12
    ret
op_VAR_print_char:
    addi sp, sp, -4
    sw ra, 0(sp)
    # no mv a0, a0 needed since operand is already in a0
    call PRINT_NON_COMPRESSED_ZSCII_CHAR
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_VAR_print_num:
    addi sp, sp, -4
    sw ra, 0(sp)
    call PRINT_NUM_AS_DEC
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_VAR_random:
    # a0 = range N
    # N > 0 : store random value in [1..N]
    # N < 0 : seed RNG with -N and store 0
    # N = 0 : reseed to deterministic default and store 0
    # RNG: 16-bit xorshift (no mul/div)
    addi sp, sp, -4
    sw ra, 0(sp)

    bgt a0, zero, random_generate

    # Seeding path for N <= 0
    beq a0, zero, random_seed_zero
    sub t0, zero, a0          # t0 = -N for negative N
    j random_seed_apply

random_seed_zero:
    li t0, 0xACE1             # deterministic default seed

random_seed_apply:
    # keep seed as unsigned 16-bit and avoid zero lockup state
    slli t0, t0, 16
    srli t0, t0, 16
    bne t0, zero, random_seed_store
    li t0, 1

random_seed_store:
    la t1, RNG_STATE
    sw t0, 0(t1)
    li a0, 0
    call DO_STORE_FROM_BYTE
    j random_done

random_generate:
    # N is positive; use N as unsigned 16-bit for range reduction
    slli t5, a0, 16
    srli t5, t5, 16

    # load state
    la t0, RNG_STATE
    lw t1, 0(t0)
    slli t1, t1, 16
    srli t1, t1, 16
    bne t1, zero, random_step_1
    li t1, 1

random_step_1:
    # x ^= x << 7
    slli t2, t1, 7
    xor t1, t1, t2
    slli t1, t1, 16
    srli t1, t1, 16

    # x ^= x >> 9
    srli t2, t1, 9
    xor t1, t1, t2
    slli t1, t1, 16
    srli t1, t1, 16

    # x ^= x << 8
    slli t2, t1, 8
    xor t1, t1, t2
    slli t1, t1, 16
    srli t1, t1, 16

    bne t1, zero, random_state_store
    li t1, 1

random_state_store:
    sw t1, 0(t0)

    # r = x mod N using repeated subtraction (no div)
    mv t2, t1
random_mod_loop:
    bltu t2, t5, random_mod_done
    sub t2, t2, t5
    j random_mod_loop

random_mod_done:
    addi t2, t2, 1            # map to 1..N
    mv a0, t2
    call DO_STORE_FROM_BYTE

random_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_VAR_push:
    addi sp, sp, -4
    sw ra, 0(sp)
    mv a1, a0
    li a0, 0
    call DO_WRITE
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_VAR_pull:
    # pop the top of the stack and store it in the variable referenced in a0
    addi sp, sp, -4
    sw ra, 0(sp)
    Z_POP(a1)
    call DO_WRITE
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_VAR_split_window:
    ebreak
    ret
op_VAR_set_window:
    ebreak
    ret
op_output_stream:
    ebreak
    ret
op_input_stream:
    ebreak
    ret

# 2-operand opcode stubs
# for all of the following, assume operand 1 is in a0, operand 2 is in a1
op_2OP_jeq:
    # je tests if op1 == op2 (and optionally == op3 or == op4)
    # op1 in a0, op2 in a1, op3 in a2, op4 in a3, count in a4
    # The count (a4) will be exactly 2 for standard 2OPs, or 2, 3, 4 for VAR form.
    # We branch if ANY of the test operands equal op1.
    
    # check op1 == op2
    beq a0, a1, jeq_true
    
    # check if we have more than 2 operands
    li t0, 2
    ble a4, t0, jeq_false
    
    # check op1 == op3
    beq a0, a2, jeq_true
    
    # check if we have more than 3 operands
    li t0, 3
    ble a4, t0, jeq_false
    
    # check op1 == op4
    beq a0, a3, jeq_true
    
jeq_false:
    li a0, 0
    j DO_BRANCH
jeq_true:
    li a0, 1
    j DO_BRANCH
op_2OP_jl:
    # jl a b?(label)
    # jump if a < b
    slt a0, a0, a1 # if a0 < a1, a0 = 1, else a0 = 0
    j DO_BRANCH
op_2OP_jg:
    # jg a b?(label)
    # jump if a > b
    slt a0, a1, a0 # if a1 < a0, a0 = 1, else a0 = 0
    j DO_BRANCH
op_2OP_dec_chk:
    # dec_chk (variable) value?(label)
    addi sp, sp, -16
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)

    mv s1, a0 # move the variable number into s1
    mv s2, a1 # move the comparison value into s2
    
    # sign extend s2 from 16 to 32 bits
    slli s2, s2, 16
    srai s2, s2, 16
    
    call DO_READ # a0 is the variable number we use for this...
    addi a1, a0, -1 # decrement the value, and store it in a1 for the DO_WRITE routine
    mv s3, a1 # save the new value in s3, to avoid re-looking up
    mv a0, s1 # move the variable number into a0
    call DO_WRITE
    
    # sign extend s3 from 16 to 32 bits
    slli s3, s3, 16
    srai s3, s3, 16
    
    # branch if variable < value
    slt a0, s3, s2 # if s3 (new var value) < s2 (arg2), a0 = 1, else a0 = 0
    
    lw s3, 12(sp)
    lw s2, 8(sp)
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 16
    
    # now we can just jump to the branch handler
    j DO_BRANCH
    ret
op_2OP_inc_chk:
    addi sp, sp, -16
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)

    mv s1, a0 # move the variable number into s1
    mv s2, a1 # move the comparison value into s2
    
    # sign extend s2 from 16 to 32 bits
    slli s2, s2, 16
    srai s2, s2, 16
    
    call DO_READ # a0 is the variable number we use for this...
    addi a1, a0, 1 # increment the value, and store it in a1 for the DO_WRITE routine
    mv s3, a1 # save the new value in s3, to avoid re-looking up
    mv a0, s1 # move the variable number into a0
    call DO_WRITE
    
    # sign extend s3 from 16 to 32 bits
    slli s3, s3, 16
    srai s3, s3, 16
    
    # branch if variable > value  (i.e value < variable)
    slt a0, s2, s3 # if s2 (arg2) < s3 (new var value), a0 = 1, else a0 = 0
    
    lw s3, 12(sp)
    lw s2, 8(sp)
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 16
    
    j DO_BRANCH
op_2OP_jin:
    # a0 = object 1, a1 = object 2 (parent candidate)
    addi sp, sp, -16
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
    mv s1, a0 # obj 1
    mv s2, a1 # obj 2

    mv a0, s1 # put obj 1 in a0 for GET_OBJECT_ADDRESS
    call GET_OBJECT_ADDRESS
    # the address is already in a0
    li a1, PARENT_OFFSET
    call GET_OBJECT_RELATION
    # now, check if the parent (in a0) == obj 2 (in s2)
    beq s2, a0, op_2OP_jin_true
    li a0, 0
    j op_2OP_jin_done
op_2OP_jin_true:
    li a0, 1
op_2OP_jin_done:
    lw s3, 12(sp)
    lw s2, 8(sp)
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 16
    j DO_BRANCH
    ret
op_2OP_test:
    # test bitmap flags?(label)
    # a0 = bitmap, a1 = flags
    # does bitmask & flags == flags 
    and t0, a0, a1 # bitmask & flags
    xor t1, a1, t0 # if t1 is 0, then bitmask & flags == flags 
    slti a0, t1, 1 # if t1 is 0, a0 = 1, else a0 = 0
    j DO_BRANCH
    ret
op_2OP_or:
    # add a0 and a1, store in a0
    or a0, a0, a1
    j basic_operation_2OP_store
op_2OP_and:
    # add a0 and a1, store in a0
    and a0, a0, a1
    j basic_operation_2OP_store
op_2OP_testattr: 
    # a0 = object number, a1 = attribute number
    # save a0-a1 on stack and ra

    addi sp, sp, -24
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)

    mv s1, a0 # object number
    mv s2, a1 # attribute number
    call GET_OBJECT_ADDRESS
    # the address is already in a0
    mv a1, s2 # attribute number
    call CHECK_OBJECT_ATTRIBUTE
    # restore s1-s3 and ra
    lw s3, 12(sp)
    lw s2, 8(sp)
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 24
    j DO_BRANCH
    ret
op_2OP_setattr:
    # a0 = object number, a1 = attribute number
    # save a0-a1 on stack and ra

    addi sp, sp, -24
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)

    mv s1, a0 # object number
    mv s2, a1 # attribute number
    call GET_OBJECT_ADDRESS
    # the address is already in a0
    mv a1, s2 # attribute number
    call SET_OBJECT_ATTRIBUTE
    # restore s1-s3 and ra
    lw s3, 12(sp)
    lw s2, 8(sp)
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 24
    ret
op_2OP_clear_attr:
    # a0 = object number, a1 = attribute number
    # save a0-a1 on stack and ra

        addi sp, sp, -24
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)

    mv s1, a0 # object number
    mv s2, a1 # attribute number
    call GET_OBJECT_ADDRESS
    # the address is already in a0
    mv a1, s2 # attribute number
    call CLEAR_OBJECT_ATTRIBUTE
    # restore s1-s3 and ra
    lw s3, 12(sp)
    lw s2, 8(sp)
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 24
    ret
op_2OP_store:
    # just moves the value in a1 to the variable address in a0
    # save ra

    addi sp, sp, -4
    sw ra, 0(sp)
    call DO_WRITE
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_2OP_insert_obj:
    # a0 = object number, a1 = parent object number
    addi sp, sp, -4
    sw ra, 0(sp)
    call INSERT_OBJECT_INTO_TREE
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
op_2OP_loadw:
    # save return address since we call a routine
    addi sp, sp, -4
    sw ra, 0(sp)

    # a0 = array, a1 = index
    # zero extend to ensure they are treated as unsigned offsets
    slli a0, a0, 16
    srli a0, a0, 16
    slli a1, a1, 16
    srli a1, a1, 16

    slli a1, a1, 1 # multiply the index by 2
    add a0, a0, a1 # a0 = Z-machine address of the value
    # Add Z_CODE_BASE to get native address
    la t0, Z_CODE_BASE
    add a0, a0, t0
    
    call READ_HALFWORD_BE
    # a0 now has the value
    
    # restore return address before jumping to store routine
    lw ra, 0(sp)
    addi sp, sp, 4
    
    # now, do whatever the "store" byte says... (only jump so og 
    # return address is preserved)
    
    j DO_STORE_FROM_BYTE
    ret
op_2OP_loadb:
    # save return address since we call a routine
    addi sp, sp, -4
    sw ra, 0(sp)

    # a0 = array, a1 = index
    # zero extend array and index to ensure they are treated as unsigned
    slli a0, a0, 16
    srli a0, a0, 16
    slli a1, a1, 16
    srli a1, a1, 16

    add a0, a0, a1 # a0 = Z-machine address of the value
    # Add Z_CODE_BASE to get native address
    la t0, Z_CODE_BASE
    add a0, a0, t0
    
    call READ_BYTE
    # a0 now has the value
    
    # restore return address before jumping to store routine
    lw ra, 0(sp)
    addi sp, sp, 4
    
    # now, do whatever the "store" byte says... (only jump so og 
    # return address is preserved)
    
    j DO_STORE_FROM_BYTE
    ret
op_2OP_get_prop:
    # a0 = object number, a1 = property number
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    mv s1, a0
    mv s2, a1

    call GET_OBJECT_ADDRESS
    # the address is already in a0
    mv a1, s2
    call GET_OBJECT_PROPERTY
    
    call DO_STORE_FROM_BYTE
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret
op_2OP_get_next_prop:
    # get_next_prop object property → (result)
    # we're gonna do this in a stupid naive way... just call 
    # GET_OBJECT_ADDRESS_OF_SPECIFIC_PROPERTY in a loop, until we hit a "yes", starting at
    # 1+ the property number we were given. If we hit 32, we return 0. 
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    mv s2, a1 # property number
    # pass it the object num
    call GET_OBJECT_ADDRESS
    mv s1, a0 # object address
find_next_prop_loop:
    addi a0, s2, 1 # check the next property number
    li t0, 32
    beq a0, t0, not_found
    call GET_OBJECT_ADDRESS_OF_SPECIFIC_PROPERTY
    bne a0, zero, found_prop
    j find_next_prop_loop
not_found:
    mv a0, zero
    j get_n_prop_finish
found_prop:
    mv a0, s2 # move the property number back to a0 for the DO_STORE routine
get_n_prop_finish:
    call DO_STORE_FROM_BYTE
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret
op_2OP_get_prop_addr:
    # get_prop_addr object property → (result)
    # a0 = object number, a1 = property number
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    mv s1, a0
    mv s2, a1
    call GET_OBJECT_ADDRESS
    # a0 now holds the object address in memory
    mv a1, s2 # restore property number to a1
    call GET_OBJECT_ADDRESS_OF_SPECIFIC_PROPERTY
    # a0 now holds address of property's size/id byte, or 0 if not found
    beq a0, zero, prop_addr_not_found
    # The property data starts immediately after the size/id byte
    addi a0, a0, 1
    la t0, Z_CODE_BASE
    sub a0, a0, t0
prop_addr_not_found:
    mv a1, a0               # the value to store must be in a1 for DO_STORE_FROM_BYTE / DO_WRITE
    call DO_STORE_FROM_BYTE # reads the destination byte and writes a1 there
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret
op_2OP_add:
    # add a0 and a1, store in a0
    add a0, a0, a1
    # cut to 16 bits, and sign extend
basic_operation_2OP_store:
    # now, do whatever the "store" byte says... (only jump so og 
    # return address is preserved)
    j DO_STORE_FROM_BYTE
    
    ret
op_2OP_sub:
    # add a0 and a1, store in a0
    sub a0, a0, a1
    j basic_operation_2OP_store
op_2OP_mul:
    addi sp, sp, -4
    sw ra, 0(sp)
    call MATH_MUL
    lw ra, 0(sp)
    addi sp, sp, 4
    j DO_STORE_FROM_BYTE
    ret
.data
.text
op_2OP_div:
    addi sp, sp, -4
    sw ra, 0(sp)
    call MATH_DIV
    lw ra, 0(sp)
    addi sp, sp, 4
    j DO_STORE_FROM_BYTE
    ret
op_2OP_mod:
    addi sp, sp, -4
    sw ra, 0(sp)
    call MATH_MOD
    lw ra, 0(sp)
    addi sp, sp, 4
    j DO_STORE_FROM_BYTE
    ret

