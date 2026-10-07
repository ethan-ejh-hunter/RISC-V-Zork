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
# routines:
#  DO_RETURN - common return routine for Z-machine opcodes that return values
#           to their callers.
#  DO_CALL - common call routine for Z-machine opcodes that call routines
#  DO_WRITE - common write routine for Z-machine opcodes that write to 
#             variables (stack, globabls, locals)
#  DO_READ - common read routine for Z-machine opcodes that read from
#            variables (stack, globals, locals)
#  DO_STORE_FROM_BYTE - common routine for Z-machine opcodes that store a value
#                       from a byte read from Z_PC
#  GET_VARIABLE_OPERANDS - common routine for Z-machine opcodes that get
#                           variable operands
#  GET_SHORT_OPERAND - common routine for Z-machine opcodes that get
#                       short form operand
#  GET_LONG_OPERANDS - common routine for Z-machine opcodes that get
#                       long operands
#  GET_1OPERAND - common routine for Z-machine opcodes that get
#                 1 operand
#  DO_BRANCH - common routine for Z-machine opcodes that branch
#
############################################################################# 
# temporary operand storage



.text



.global DO_WRITE
# write to a variable (stack, globals, locals)
DO_WRITE:
    # a0 = variable number
    # a1 = value to write
    # save *actual* return address to non-z stack
    addi sp, sp, -4
    sw ra, 0(sp)
    # decide where to write based on variable number
    # 0 = stack
    # 1-15 = local variables
    # 16-255 = global variables
    
    beq a0, x0, write_stack
    li t0, 16
    blt a0, t0, write_local
    j write_global

write_stack:
    # write to z-stack
    Z_PUSH(a1)
    j write_cleanup

write_local:
    # write to local variable
    # Locals start at Z_FP - 64 and grow upward
    # Variable 1 (L00) is at Z_FP - 64
    # Variable N is at Z_FP - 64 + (N-1)*4
    addi a0, a0, -1      # convert to 0-based index
    slli a0, a0, 2       # multiply by 4
    add t1, Z_FP, a0     # Z_FP + (var-1)*4
    # Z_FP + (var-1)*4
    sw a1, 0(t1)         # write the value to local variable
    j write_cleanup

write_global:
    # write to global variable
    # subtract 16 from variable number to get index
    li t0, 16
    sub t1, a0, t0
    # each global variable is 2 bytes
    slli t1, t1, 1      # multiply index by 2
    la t2, GLOBAL_TABLE_LOCATION
    lw t2, 0(t2)        # load the actual address of the global table
    add a0, t2, t1      # calculate address of global variable
    call WRITE_HALFWORD_BE  # write the halfword to global variable
    j write_cleanup

write_cleanup: 
    # restore return address and return
    lw ra, 0(sp)
    addi sp, sp, 4
    ret



.global GET_1OPERAND
GET_1OPERAND:
    # inputs: a0 = operand type
    # outputs: a0 = operand value
    # modifies: Z_PC
    # save the ra
    addi sp, sp, -4
    sw ra, 0(sp)
    beq a0, x0, get_large_constant
    li t1, 1
    beq a0, t1, get_small_constant
get_variable:
    # variable
    # read variable number from Z-code
    INGEST_NEXT_BYTE(a0)
    mv t2, a0         # t2 = variable number
    # now read variable value into a0
    mv a0, t2         # a0 = variable number
    call DO_READ
    j oneop_done
get_large_constant:
    INGEST_NEXT_BE_HALFWORD(a0)
    # large constants are also 16-bit sign extended
    slli a0, a0, 16
    srai a0, a0, 16
    j oneop_done
get_small_constant:
    INGEST_NEXT_BYTE(a0)
oneop_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
# this is for short form opcodes, to get their operand...

.global GET_SHORT_OPERAND
GET_SHORT_OPERAND:
    # modifies Z_PC
    # like all other getters, expects you to have ingested
    # the main byte already
    # returns: a0 = operand
    addi sp, sp, -4
    sw ra, 0(sp)

    addi Z_PC, Z_PC, -1
    INGEST_NEXT_BYTE(a0)
    li t0, SHORT_FORM_OPERAND_TYPE_MASK
    and t1, s1, t0
    srli a0, t1, 4 # shift it down to bottom
    call GET_1OPERAND
    # result in a0
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
    


# this is for the non-var, long form (so 2 operands)
.globl GET_LONG_OPERANDS
GET_LONG_OPERANDS:
    # modifies: Z_PC
    # returns: a0 = operand 1
    #          a1 = operand 2
    # save the ra and s1-s2
    # expects Z_PC to be pointing past the opcode
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)


    # get the opcode...
    addi Z_PC, Z_PC, -1        # a0 = address of byte
    INGEST_NEXT_BYTE(s1)
    # save that byte
    mv s1, a0         
    # now read the first operand...
    # bit 6 is the type for the first operand
    li t0, 0x40
    and t1, s1, t0
    srli t2, t1, 6 # shift it down to bottom (now it's 0 or 1)
    addi a0, t2, 1 # add 1 (so 0->1 (small const), 1->2 (variable))
    # now we have the operand type in a0
    call GET_1OPERAND
    # result in a0
    mv s2, a0
    # get second operand...
    # bit 5 is the type for the second operand
    li t0, 0x20
    and t1, s1, t0
    srli t2, t1, 5 # shift it down to bottom (now it's 0 or 1)
    addi a0, t2, 1 # add 1 (so 0->1 (small const), 1->2 (variable))
    # now we have the operand type in a0
    call GET_1OPERAND
    # result in a0
    mv a1, a0
    mv a0, s2
    li a4, 2       # Set the operand count to exactly 2 (for 2OP opcodes)
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret

.globl GET_VARIABLE_OPERANDS
GET_VARIABLE_OPERANDS:
    # parses the operands for a VARIABLE form
    # opcode byte has not been consumed
    # 
    # Output: 
    # a0 = operand 1
    # a1 = operand 2
    # a2 = operand 3
    # a3 = operand 4 (if present)
    # a4 = num of operands
    #
    # modifies Z_PC
    # assumes it starts after the opcode byte
    
    # save callee-saved registers
    addi sp, sp, -36
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    sw s2, 12(sp) # loop index
    sw s3, 16(sp) # operands byte
    sw s4, 20(sp) # op 1
    sw s5, 24(sp) # op 2
    sw s6, 28(sp) # op 3
    sw s7, 32(sp) # op 4
    
    # get the operands byte
    INGEST_NEXT_BYTE(s3)
    mv s3, a0
    li s2, 0    # current operand index
    li s1, 4    # max operands (check 4 pairs of bits)

get_operand_loop:
    beq s2, s1, get_operand_done
    andi t0, s3, MSB_TWO_BITS # get top 2 bits
    srli a0, t0, 6      # shift to bottom
    li t1, 3
    beq a0, t1, get_operand_done # 11 binary = omitted -> done
    
    # fetch operand
    # a0 is operand type (0, 1, 2)
    call GET_1OPERAND
    # result in a0
    
    # store in appropriate s-register
    li t0, 0
    beq s2, t0, store_op1
    li t0, 1
    beq s2, t0, store_op2
    li t0, 2
    beq s2, t0, store_op3
    li t0, 3
    beq s2, t0, store_op4
    j cleanup_loop_iter

store_op1:
    mv s4, a0
    j cleanup_loop_iter
store_op2:
    mv s5, a0
    j cleanup_loop_iter
store_op3:
    mv s6, a0
    j cleanup_loop_iter
store_op4:
    mv s7, a0
    j cleanup_loop_iter

cleanup_loop_iter:
    addi s2, s2, 1
    # shift s3 left by 2 bits to get next type
    slli s3, s3, 2
    j get_operand_loop

get_operand_done:
    # restore registers
    # setup return values
    mv a0, s4   # operand 1
    mv a1, s5   # operand 2
    mv a2, s6   # operand 3
    mv a3, s7   # operand 4
    mv a4, s2   # count
    
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    lw s2, 12(sp)
    lw s3, 16(sp)
    lw s4, 20(sp)
    lw s5, 24(sp)
    lw s6, 28(sp)
    lw s7, 32(sp)
    addi sp, sp, 36
    ret
    
    

.global DO_CALL
DO_CALL:
    # this handles many of the housekeeping tasks for calling a Z-machine routine
    # a0 = Z-PC to call (NOTE! THIS IS PAST THE ROUTINE HEADER BYTE). 
    # Also ensure this is in native address format (RISC-V addressing)
    # a1 = return location
    # a2 = number of arguments
    # a3 = arg 1
    # a4 = arg 2
    # a5 = arg 3
    # a6 = arg 4
    # and that the Z-PC is a packed address (for machine Z3)

    # save a2 (num args) plus 1 (since local variable 0 is the stack) 
    # to s4 for later use... a2 might get clobbered
    # allocate 40 bytes on stack (for ra and s0-s8)
    addi sp, sp, -40
    # save link register
    sw ra, 36(sp)
    # save frame pointer
    sw s0, 32(sp)
    sw s1, 28(sp)
    sw s2, 24(sp)
    sw s3, 20(sp)
    sw s4, 16(sp)
    # save extra registers for args
    sw s5, 12(sp)
    sw s6, 8(sp)
    sw s7, 4(sp)
    sw s8, 0(sp)

    addi s0, sp, 40      # s0 = new frame pointer

    mv s4, a2 # num args
    # save args to s-registers
    mv s5, a3
    mv s6, a4
    mv s7, a5
    mv s8, a6

    # general steps...
    # save the next old instruction
    Z_PUSH(Z_PC)    # Z_PC = next Z-PC instruction
    # save the old Z-stack frame pointer
    Z_PUSH(Z_FP)    # Z_FP = old stack frame floor
    Z_PUSH(a1)     # save return location
    mv Z_PC, a0     # move the new Z-PC into the Z-PC register
    
    # allocate space for local variables (16 * 4 = 64 bytes)
    # move stack frame floor pointer down by 64 bytes...
    # we will use it as an iterator to clear locals before setting defaults
    addi Z_FP, Z_SP, -64
    mv Z_SP, Z_FP     # Update Z_SP to point to the bottom of the stack frame (below locals)
    # copy default local variable values (if any)
    # start by zeroing all locals
    li t0, 0
    li t1, 16          # 16 local variables
    mv t2, Z_FP        # Use t2 as temp iterator to preserve Z_FP
zero_locals_loop:
    beq t1, x0, locals_zeroed
    sw t0, 0(t2)       # write 0 to local variable (using t2)
    addi t2, t2, 4     # move to next local variable (increment t2)
    addi t1, t1, -1
    j zero_locals_loop
locals_zeroed:
    
    # now, we copy the default values from the routine header
    # first, get the address of the routine header...
    # a0 = Z-PC of routine to call
    addi s1, Z_PC, 1          # s1 = address of second byte of routine header
    INGEST_NEXT_BYTE(a0)
    # increment it past all of the default values
    slli t0, a0, 1
    add Z_PC, Z_PC, t0
    # first byte is number of local variables
    addi s2, a0, 1              # s2 = index of last default local variable (since var 0 is z-stack)
    # move s1 to point to first default local variable value
    
    # now read each default local variable value and copy to locals
    li s3, 1                # s3 = index of current default local variable (start at 1)
copy_defaults_loop:
    beq s3, s2, done_copy_defaults  # if all defaults copied, move to copying args
    # ebreak
    # read next default value
    mv a0, s1                 # a0 = address to read from
    call READ_HALFWORD_BE
    # a0 = default value
    # write to local variable
    mv a1, a0            # a1 = value to write
    mv a0, s3            # a0 = local variable number
    call DO_WRITE
    addi s1, s1, 2      # move to next default local variable value
    addi s3, s3, 1      # increment local variable index
    j copy_defaults_loop 

done_copy_defaults:
    # copy arguments to locals
    # s4 = num args
    li t0, 0
    beq s4, t0, call_setup_done
    
    # Arg 1 (s5) -> Local 1
    li a0, 1
    mv a1, s5
    call DO_WRITE
    
    li t0, 1
    beq s4, t0, call_setup_done
    
    # Arg 2 (s6) -> Local 2
    li a0, 2
    mv a1, s6
    call DO_WRITE
    
    li t0, 2
    beq s4, t0, call_setup_done
    
    # Arg 3 (s7) -> Local 3
    li a0, 3
    mv a1, s7
    call DO_WRITE
    
    li t0, 3
    beq s4, t0, call_setup_done
    
    # Arg 4 (s8) -> Local 4
    li a0, 4
    mv a1, s8
    call DO_WRITE
    
    # Assuming max 4 args for now
    
call_setup_done:
    # ready to jump to the routine now
    lw ra, 36(sp)         # restore actual return address
    lw s0, 32(sp)
    lw s1, 28(sp)
    lw s2, 24(sp)
    lw s3, 20(sp)
    lw s4, 16(sp)
    lw s5, 12(sp)
    lw s6, 8(sp)
    lw s7, 4(sp)
    lw s8, 0(sp)
    addi sp, sp, 40       # deallocate stack space
    
    ret

.global DO_RETURN
# do return for any opcode that returns a value from a Z-machine routine
DO_RETURN:
    # a0 = Z-PC return value
    # Z_FP = stack frame floor
    # Z_SP = stack pointer
    
    # move z-stack pointer to frame floor, and then past the 
    # locals (since we don't care)
    # so start by pushing the stack pointer back down to that
    addi Z_SP, Z_FP, 64    # (64 bytes of locals locals)

    # get return location from z-stack). the z-stack pointer should now be 
    # at the return location
    lw t1, 0(Z_SP)        # load return location from z-stack
    addi Z_SP, Z_SP, 4      # move z-stack pointer up again

    # Next, pop the old z-stack frame pointer
    lw Z_FP, 0(Z_SP)       # old z-stack frame floor is at offset 0
    addi Z_SP, Z_SP, 4      # move z-stack pointer up
    # Jump to the correct Z-PC return address
    lw Z_PC, 0(Z_SP)       # load return address from z-stack
    addi Z_SP, Z_SP, 4      # move z-stack pointer up
    # write the return value to the correct location
    addi sp, sp, -4
    sw ra, 0(sp)        # save actual return address
    # return value is *already* in a0 from when we called func
    mv a1, a0        # value to write
    mv a0, t1        # location to write return value
    call DO_WRITE
    lw ra, 0(sp)        # restore actual return address
    addi sp, sp, 4
    ret
.globl DO_STORE_FROM_BYTE
DO_STORE_FROM_BYTE:
    # this routine is specifically for the common case of 
    # needing to read the byte that Z_PC points to, and storing 
    # some value to that...
    # inputs: a0 -- value to store
    # outputs: none
    # side effects: shoves Z_PC forward by 1
    # save ra and s1
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s1, 4(sp)
    mv s1, a0
    # get the byte
    INGEST_NEXT_BYTE(a0)
    # don't add here, we add later. 
    # store the new value in a1 (value)
    # location from before is already in a0 (variable)
    mv a1, s1
    # a0 is already correct
    call DO_WRITE
    
    # restore ra and s1
    lw ra, 0(sp)
    lw s1, 4(sp)
    addi sp, sp, 8
    ret
    

DO_READ:
    # a0 = variable number
    # returns value in a0
    addi sp, sp, -4
    sw ra, 0(sp)
    # decide where to read based on variable number
    # 0 = stack
    # 1-15 = local variables
    # 16-255 = global variables

    # # define an ecall to print "R: "
    # li t0, 0x10015610
    # blt Z_PC, t0, skip_read_debug
    # addi sp, sp, -4
    # sw a0, 0(sp)
    # li a0, 'R'
    # li a7, 11
    # ecall
    # li a0, ':'
    # li a7, 11
    # ecall
    # li a0, ' '
    # li a7, 11
    # ecall
    # lw a0, 0(sp)
    # # print var num
    # li a7, 1
    # ecall
    # li a0, ' '
    # li a7, 11
    # ecall
    # lw a0, 0(sp)
    # addi sp, sp, 4
# skip_read_debug:

    beq a0, x0, read_stack
    li t0, 16
    blt a0, t0, read_local
    j read_global

read_stack:
    # pop from z-stack
    Z_POP(a0)
    j read_cleanup

read_local:
    # read from local variable
    # Locals start at Z_FP - 64 and grow upward
    # Variable 1 (L00) is at Z_FP - 64
    # Variable N is at Z_FP - 64 + (N-1)*4
    addi a0, a0, -1      # convert to 0-based index
    slli a0, a0, 2       # multiply by 4
    add t1, Z_FP, a0     # Z_FP + (var-1)*4
    # Z_FP + (var-1)*4
    lw a0, 0(t1)         # load the value
    j read_cleanup

read_global:
    # read from global variable
    # subtract 16 from variable number to get index
    li t0, 16
    sub t1, a0, t0
    # each global variable is 2 bytes
    slli t1, t1, 1      # multiply index by 2
    la t2, GLOBAL_TABLE_LOCATION
    lw t2, 0(t2)        # load the actual address of the global table
    add a0, t2, t1      # calculate address of global variable
    call READ_HALFWORD_BE  # read the halfword from global variable

read_cleanup: 
    # sign extend the 16-bit value in a0 to full 32-bits
    slli a0, a0, 16
    srai a0, a0, 16

    # restore return address and return
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

.globl DO_BRANCH
DO_BRANCH:
    # this routine handles the store byte
    # expects the Z_PC to be one before the store byte (or pointing to
    # the last byte of the operands)
    # a0 = whether the condition was true (1) or false (0)
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)
    mv s0, a0 # save the result in s0

    # read the branch byte...
    INGEST_NEXT_BYTE(a0)
    # save that first byte...
    # decice whether we should branch or just skip stuff...
    # if high bit is set, we branch on true,
    # otherwise branch on false.
    li t0, 0x80
    and t0, a0, t0
    srai t0, t0, 7 # shift the high bit into the lowest bit
    xor t0, s0, t0 # if s0(result) == t0(condition bit), xor is 0.
    beq t0, x0, run_branch
no_branch:
    li t0, 0x40
    and t0, a0, t0
    bne t0, x0, only_one_byte_no_branch
two_byte_no_branch:
    addi Z_PC, Z_PC, 1 # if it's 2 byte offset, move past the second byte (first was ingested)
only_one_byte_no_branch:
    # restore ra and s0
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    addi sp, sp, 12
    ret
run_branch:
    # get how far to branch... (lower 6 bits)
    li t1, 0x3F
    and t1, a0, t1 # Use a0 (branch byte), not s0!
    # just keep it in t1, as the 1 byte branch
    # is diff than 2 byte branch. Don't shift it back
    # to save 1 instruction
    li t0, 0x40
    and t0, a0, t0 # Use a0 (branch byte)
    mv s1, t1 # store 
    beq t0, x0, two_byte_branch
only_one_byte_branch:
    j done_branch
two_byte_branch:
    # sign extend it...
    # 14 bit value.
    # byte 1 (a0) & 0x3F is top 6 bits.
    # byte 2 is bottom 8 bits.
    # we have top 6 bits in s1 (from a0 & 0x3F).
    
    # Ingest next byte
    INGEST_NEXT_BYTE(s1)
    # a0 has bottom 8 bits.
    # s1 has top 6 bits.
    slli s1, s1, 8
    or s1, s1, a0
    # sign extend the 14 bit number to 32 bits
    slli s1, s1, 18
    srai s1, s1, 18

    
done_branch:
    # check if the branch is 0 or 1
    beq s1, x0, return_from_branch
    li t0, 1
    beq s1, t0, return_from_branch
    # if we reach here, s1 is a normal offset (could be negative)
    
    # actual branch address calculation:
    # PC + Offset - 2
    # Offset is in s1.
    addi s1, s1, -2
    add Z_PC, Z_PC, s1
    # restore ra and s0
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    addi sp, sp, 12
    ret
return_from_branch:
    # we now know it's either 0 or 1
    mv a0, s1
    # restore saved stack and registers, so 
    # DO_RETURN can save them again, lol. 
    lw ra, 0(sp)
    lw s0, 4(sp)
    lw s1, 8(sp)
    addi sp, sp, 12
    j DO_RETURN
    


    
    
    