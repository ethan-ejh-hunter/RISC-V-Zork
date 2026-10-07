############################################################################
# 
# Filename: strings.s
#
# Author: Ethan Hunter
# Class: ECEN 423, Section 1, Winter 2026
# Date: 1/10/2026
#
# Description: provides utility routines for handling ASCII and ZSCII strings
#
# Functions:
#
############################################################################# 

.data
# points to the current Z-string
.global CURRENT_ZCHAR_ADDR
CURRENT_ZCHAR_ADDR:
    .word 0
# this is the index of the current 5-bit character within the current Z-character word
# 0 = first 5 bits, 1 = second 5 bits, 2 = last 5 bits
.global CURRENT_ZCHAR_INDEX
CURRENT_ZCHAR_INDEX:
    .word 0

# this macro sets up the global state necessary for get-Z-char and others... 
# basically just the "current char" pointer and the variable for which 5 bit char we're on.
.macro Z_STRING_INIT(%zstring_addr_reg, %scratch_reg)
    # initializes Z-machine string reading state
    # zstring_addr_reg - register containing address of Z-string in memory
    la %scratch_reg, CURRENT_ZCHAR_ADDR
    sw %zstring_addr_reg, 0(%scratch_reg)   # set CURRENT_ZCHAR_ADDR to zstring_addr_reg
    la %scratch_reg, CURRENT_ZCHAR_INDEX
    sw x0, 0(%scratch_reg)                  # set CURRENT_ZCHAR_INDEX to 0
.end_macro

# because Z-strings support "abreviations" we may need to start reading another string
# while we're in the middle of reading one. To support this, we need to be able to
# push and pop the current string state (current address and current index)
.macro PUSH_STRING_STATE(%scratch_reg)
    addi sp, sp, -8
    # pushes the current Z-string reading state onto the stack
    # scratch_reg - a scratch register to use
    la %scratch_reg, CURRENT_ZCHAR_ADDR
    lw %scratch_reg, 0(%scratch_reg)
    # push it to the stack...
    sw %scratch_reg, 0(sp)
    la %scratch_reg, CURRENT_ZCHAR_INDEX
    lw %scratch_reg, 0(%scratch_reg)
    sw %scratch_reg, 4(sp)                     # push CURRENT_ZCHAR_INDEX
    
.end_macro
.macro POP_STRING_STATE(%scratch_val, %scratch_addr)
    # pops the current Z-string reading state from the stack
    # scratch_reg - a scratch register to use
    lw %scratch_val, 0(sp)
    la %scratch_addr, CURRENT_ZCHAR_ADDR
    sw %scratch_val, 0(%scratch_addr)  # set CURRENT_ZCHAR_ADDR
    lw %scratch_val, 4(sp)
    la %scratch_addr, CURRENT_ZCHAR_INDEX
    sw %scratch_val, 0(%scratch_addr)   # set CURRENT_ZCHAR_INDEX
    addi sp, sp, 8
.end_macro

.text
# PUT_CHAR puts a character onto one of, well, kinda 4 streams? 
# stream 0 is vga. It does word wrapping and fancy stuff
# stream 1 is... nothing (blank space so it matches with z-machine streams)
# stream 2 is for writing to memory (used for building strings, I think? 
#   Will implement later if we need it)
# stream 3 is for writing to the script. If I get bored, I could have it output to
#   the serial port, but for now it just gets discarded.
# Inputs: 
#   a0 - character to print (as ascii)
#   a1 - stream number (0-3)
# Outputs:
#   none
PUT_CHAR:
# PRINT_ZSCII_STRING prints a ZSCII string to the vga
# Inputs:
#   a0 - address of ZSCII string in memory (this is an *actual* address, 
#        not Z-byte or packed address)
# Outputs:
#   none
# for now, just immediately jump to the actual function... PUT_SCREEN_CHAR. 
# Dont call, so we don't have to save/restore registers
    j PUT_SCREEN_CHAR

.global PRINT_ZSCII_STRING
PRINT_ZSCII_STRING:
    # save the current return register, and s0, to the normal stack
    addi sp, sp, -16
    sw ra, 0(sp)
    sw s2, 4(sp)
    sw s3, 8(sp)
    sw s4, 12(sp)
    mv s2, x0 # clear the current alphabet register
    # we are also storing the current alphabet 2 bits in s2
    # since this can be called recursively, push the string state
    # (in case we got called to grab an abbreviation)
    PUSH_STRING_STATE(t0)
    Z_STRING_INIT(a0, t0)   # initialize string reading state
    # now, we've got the string reading state set up... call GET_Z_CHAR
read_string_loop:
    call GET_Z_CHAR
    # save whether this is last char to s3
    mv s3, a1
    # check if it's a special character...
    # first, ZSCII space (char 0x0)
    beq a0, x0, space
    # next, is it both alphabet 2 and char 6?
    li t0, 2
    bne s2, t0, not_alph_2
    li t0, 6
    beq a0, t0, newline
    # this means's that it's a newline or a space... now, just check if it's
    # one of the shift characters or an abbreviation
    # they don't care which alphabet we're in rn
not_alph_2:
    # is it less than 4 (i.e. an abbreviation)
    li t0, 4
    blt a0, t0, abbreviation
    # so, to check if it's one of the two, use a bitmask...
    # first, clear last bit... (we can just and it with a sign extended immediate)
    andi t0, a0, ALL_BUT_LAST_BIT
    # now, check if that one is 0x4
    li t1, 4
    bne t0, t1, normal_char
    # so we need to do one of the two shifts, since it's 4 or 5
    # just subtract 3 from them, so char 4 turns into alphabet 1, 
    # and char 5 turns into alphabet 2
    addi s2, a0, -3
    j check_done
space:
    li a0, SPACE
    li a1, 0
    call PUT_CHAR
    j check_done
#here's where we handle the nested mess that is abbreviations
abbreviation:
    # so the abbreviation table no is in a0, and the next char is the offset into that. 
    # the equation to get what we want is that the address of the ptr to the string is
    # 32 * (abbrev_no - 1) + offset + ABBREV_TABLE_OFFSET
    addi a0, a0, -1
    # multiply by 32
    slli a0, a0, 5
    mv s4, a0
    # get the next character...
    call GET_Z_CHAR
    add s4, s4, a0
    # just in case this is the last char, move return value into s3
    mv s3, a1
    # multiply by 2 to get the halfword offset
    slli s4, s4, 1
    # add the offset into the story of the abbrev table
    la t0, ABBREV_TABLE_LOCATION
    lw a0, 0(t0)
    add a0, a0, s4
    # get what it points to
    call READ_HALFWORD_BE
    # that's a word (or packed) address... convert it to a *real* address
    Z_PACKED_TO_ACTUAL(a0, a0, s4)
    # now, since it's in a0, we just call PRINT_ZSCII_STRING again...
    call PRINT_ZSCII_STRING
    # and then we're back to reading the string (but first check if that was the last char!)
    j check_done
# not_alph_2 should basically be treated as if it's a normal character... 
normal_char:
    # if it's not a special character, just print it
    # first do the alphabet lookup
    # (char, alphabet, scratch)
    ZSCII_TO_ASCII(a0, s2, t0)
    li s2, 0 # reset the alphabet register
    call PUT_CHAR
    j check_done
newline:
    li s2, 0 # reset alphabet after consuming the shift
    call NEWLINE
check_done:
    beq s3, x0, read_string_loop
cleanup_print_zstring:
    # get the final CURRENT_ZCHAR_ADDR to return in a0
    la t0, CURRENT_ZCHAR_ADDR
    lw a0, 0(t0)
    #restore the string state, in case this was an abbreviation call
    POP_STRING_STATE(t0, t1)
    # restore our registers...
    # restore our registers...
    lw ra, 0(sp)
    lw s2, 4(sp)
    lw s3, 8(sp)
    lw s4, 12(sp)
    addi sp, sp, 16
    ret

.global GET_Z_CHAR
GET_Z_CHAR:
    # gets the next Z-character (5 bits) from the current Z-string
    # inputs: none
    # returns the Z-character in a0
    # returns if it was last word in a1 (1 if last, 0 if not)
    # updates CURRENT_ZCHAR_ADDR and CURRENT_ZCHAR_INDEX accordingly
    # load the current Z-character address
    # save the return address and s1
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s1, 4(sp)
    
    la t0, CURRENT_ZCHAR_ADDR
    lw t1, 0(t0)               # t1 = CURRENT_ZCHAR_ADDR

    # load the current Z-character word
    mv a0, t1                   # a0 = CURRENT_ZCHAR_ADDR
    call READ_HALFWORD_BE       # a0 = memory[t1] (but it's BE since we're in Z-machine land)
    mv t4, a0                   # t4 = current Z-character word
    mv s1, a0                   # s1 = current Z-character word
    # load the index later, since we need that for more things
    # and t2 is obviously clobbered by the read
    la t2, CURRENT_ZCHAR_INDEX
    lw t3, 0(t2)               # t3 = CURRENT_ZCHAR_INDEX

    # extract the appropriate 5 bits
    # we will shift right by 5 bits up to 2 times, then mask
    # "and" out the lower 2 bits of the index, so we don't keep the status bit
    andi t3, t3, 3
    li t5, 2                    # marker for when we are done shifting...
extract_loop:
    beq t3, t5, extract_done    # if t3 == t5, we're done shifting
    srli t4, t4, 5               # shift right by 5
    # decrement loop counter (this way we don't need to reload the Z_CHAR_INDEX to increment it, just add and write)
    addi t5, t5, -1              

    j extract_loop
extract_done:
    li a1, 0                    # a1 = 0 (not last word)
    andi a0, t4, LAST_5_BITS           # a0 = extracted Z-character (mask to last 5 bits)
    # update CURRENT_ZCHAR_INDEX
    addi t3, t3, 1              # increment index
    li t6, 3                     # if index == 3, we need to move to next word
    bne t3, t6, cleanup_get_zchar
    la t0, CURRENT_ZCHAR_ADDR
    lw t1, 0(t0)               # t1 = CURRENT_ZCHAR_ADDR
    addi t1, t1, 2               # move to next word
    sw t1, 0(t0)                # store updated address
    li t3, 0                    # reset index
    # check the top bit of the halfword... it will be in s1 at this point.
    srli t4, s1, 15
    beq t4, x0, cleanup_get_zchar
    # if it is, we're done
    li a1, 1                    # a1 = 1 (last word)
cleanup_get_zchar:
    # store updated index (regardless of whether we moved to next halfword)
    la t2, CURRENT_ZCHAR_INDEX
    sw t3, 0(t2)
    # restore the return address and s1
    lw ra, 0(sp)
    lw s1, 4(sp)
    addi sp, sp, 8
    ret

PRINT_ASCII_STRING:

NUM_TO_HEX_STRING:

GET_LINE_TO_ZCHAR_BUFFER:
    # a0 = buffer pointer
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s1, 4(sp)
    mv s1, a0 # save buffer pointer in s1
    # read the buffer size...
    call READ_BYTE
    mv a1, a0 # save buffer size in a1
    addi a0, s1, 1  # restore buffer pointer to a0 for next read
    call GET_USER_LINE
    lw ra, 0(sp)
    lw s1, 4(sp)
    addi sp, sp, 8
    ret
    
    
GET_USER_LINE:
    # a0 = buffer pointer
    # a1 = buffer size
    addi sp, sp, -16
    sw ra, 0(sp) 
    sw s1, 4(sp) # buffer pointer
    sw s2, 8(sp) # buffer max length
    sw s3, 12(sp) # buffer index
    mv s1, a0 # save buffer pointer in s1
    mv s2, a1 # save buffer size in s2
    li s3, 0 # save buffer index in s3
get_user_line_loop:
    # is the index == size? write a null byte and exit
    beq s3, s2, get_user_line_done
    DEBUG_7SEG_IMM(0xC100)
    # get a character
    GET_CHAR(t0, t1) # macro

    # is it a backspace? 
    li t0, 8
    beq a0, t0, backspace

    # now, decide if that's a newline or carriage return

    li t0, 13
    beq a0, t0, get_user_line_done
    li t0, 10
    beq a0, t0, get_user_line_done
    ble a0, zero, get_user_line_done
    
    # convert to lowercase if it's an uppercase letter (A-Z)
    li t0, 65 # 'A'
    blt a0, t0, skip_lowercase
    li t0, 90 # 'Z'
    bgt a0, t0, skip_lowercase
    addi a0, a0, 32 # convert to lowercase
skip_lowercase:
    # otherwise, write it to the buffer
    mv a1, a0
    mv a0, s1
    call WRITE_BYTE
    # increment the index
    addi s3, s3, 1
    # increment the buffer pointer
    addi s1, s1, 1
    j get_user_line_loop

get_user_line_done:
    # write a null byte
    mv a1, x0
    mv a0, s1
    call WRITE_BYTE
    # restore the return address and s1
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    addi sp, sp, 16
    ret
backspace:
    # if index is 0, ignore
    beq s3, x0, get_user_line_loop
    # otherwise, decrement index and buffer pointer, and write a null byte to "erase"
    addi s3, s3, -1
    addi s1, s1, -1
    # now, overwrite that byte with a null byte/erase it
    mv a1, x0
    mv a0, s1
    call WRITE_BYTE
    j get_user_line_loop

    




# this will need to be updated when we actually do
# vga stuff, for now just ECALLs
PRINT_NUM_AS_DEC:
    # a0 = number to print
    # li a7, 1
    # ecall
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s1, 4(sp)
    mv s1, a0 # save number to print in s1
    # if it's 0, just print 0 and return
    bne s1, x0, num_to_str_actual_routine
    li a0, '0'
    call PUT_CHAR
    j print_num_done

num_to_str_actual_routine:
    # is it *not* negative?
    bge s1, x0, num_to_str_loop
    # so it's negative, print the minus sign and negate it
    li a0, '-'
    call PUT_CHAR
    neg s1, s1
num_to_str_loop:
    # first, do the mod 10 to get the digit to print...
    mv a0, s1
    li a1, 10
    call MATH_MOD
    # now, a0 has the last digit... convert to ascii and print it
    addi a0, a0, '0' # convert to ascii
    call PUT_CHAR
    # now, do the div 10 to get the next num we'll use for the next iteration of the loop
    mv a0, s1
    li a1, 10
    call MATH_DIV
    mv s1, a0 # save the quotient for the next iteration of the loop
    # are we not done with loop? (i.e. is num > 0?)
    bne s1, x0, num_to_str_loop
print_num_done:
    lw ra, 0(sp)
    lw s1, 4(sp)
    addi sp, sp, 8
    ret

PRINT_NON_COMPRESSED_ZSCII_CHAR:
    # a0 = char to print
    addi sp, sp, -4
    sw ra, 0(sp)
    # check, is it ascii 13 (newline)
    li t0, 13
    li a7, 11
    beq a0, t0, pchar_newline
    # check, is it ascii 0 (space)
    li t0, 0
    beq a0, t0, pchar_space
    # otherwise, just print it
    call PUT_CHAR
    j print_non_compressed_done
pchar_newline:
    li a0, '\n'
    call PUT_CHAR
    j print_non_compressed_done
pchar_space:
    li a0, ' '
    call PUT_CHAR
print_non_compressed_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
    
