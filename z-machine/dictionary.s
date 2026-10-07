
############################################################################
# 
# Filename: dictionary.s
#
# Author: Ethan Hunter
# Class: ECEN 423, Section 1, Winter 2026
# Date: 2/25/2026
#
# Description: provides utility routines for handling the dictionary and parsing it
#
# Functions:
# ASCII_TO_ZSCII - converts a string of ASCII characters to compressed ZSCII
#
#############################################################################


.globl ASCII_TO_ZSCII
ASCII_TO_ZSCII:
    # a0: string start address
    # a1: string end address (exclusive)
    addi sp, sp, -28
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
    sw s4, 16(sp)
    sw s5, 20(sp)
    sw s6, 24(sp)

    mv s1, a0       # curr string ptr
    mv s2, a1       # string end ptr
    
    li s3, 0        # Word 1 accumulator
    li s4, 0        # Word 2 accumulator
    li s5, 0        # Number of Z-chars emitted (0 to 6)

zscii_loop:
    li t0, 6
    bge s5, t0, zscii_done     # Stop if we hit 6 Z-chars
    
    li s6, 5                   # Default Z-char = 5 (pad)
    
    bge s1, s2, pack_zchar     # If past end of string, pack pad
    
    # Read the next ASCII character
    mv a0, s1
    call READ_BYTE
    addi s1, s1, 1             # Advance string pointer
    
    # Is it 'a' through 'z'? (ASCII 0x61 to 0x7A)
    li t0, 0x61
    blt a0, t0, check_punct
    li t0, 0x7A
    bgt a0, t0, check_punct
    
    # It's a lowercase letter
    addi s6, a0, -0x5B         # Convert ASCII to ZSCII
    j pack_zchar

check_punct:
    call ASCII_PUNCT_TO_ZSCII  # Check if a0 is a known punctuation
    li t0, -1
    beq a0, t0, check_separator # If -1, it's not in the table
    
    # It is a valid punctuation! The A2 ZSCII index is now in a0.
    mv s6, a0                  # Save the index to pack later
    j emit_a2_shift
    
check_separator:
    # Not a letter or valid punctuation.
    # In a real Z-machine, we might skip it or just pad.
    # We will just ignore invalid characters and keep looping.
    j zscii_loop

emit_a2_shift:
    # To emit A2, we first must pack a shift character (5)
    mv a0, s6               # Save A2 index safely in a0
    li s6, 5                # Shift character
    
    # --- PACK SHIFT CHAR ---
    li t0, 3
    bge s5, t0, pack_shift_w2
pack_shift_w1:
    slli s3, s3, 5
    or s3, s3, s6
    j shift_packed
pack_shift_w2:
    slli s4, s4, 5
    or s4, s4, s6
shift_packed:
    addi s5, s5, 1
    
    # Check if that shift char was our 6th cap
    li t0, 6
    bge s5, t0, zscii_done
    
    mv s6, a0               # Restore the actual A2 index we saved
    
pack_zchar:
    # Now pack whatever is in s6 (letter, pad, or punctuation index)
    li t0, 3
    bge s5, t0, pack_char_w2
pack_char_w1:
    slli s3, s3, 5
    or s3, s3, s6
    j char_packed
pack_char_w2:
    slli s4, s4, 5
    or s4, s4, s6
char_packed:
    addi s5, s5, 1
    j zscii_loop

zscii_done:
    # --- Apply Stop Bit ---
    li t0, 0x8000
    or s4, s4, t0
    
    # Combine Word 1 (s3) and Word 2 (s4)
    slli a0, s3, 16
    or a0, a0, s4

    # Cleanup
    lw s6, 24(sp)
    lw s5, 20(sp)
    lw s4, 16(sp)
    lw s3, 12(sp)
    lw s2, 8(sp)
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 28
    ret


.globl DICTIONARY_LOOKUP
DICTIONARY_LOOKUP:
    # a0: 32 bit value that we want to look up (it is the zscii value)
    # returns the address in a0 of the Z-machine word that matches the value
    # if no match is found, return 0
    addi sp, sp, -24
    sw ra, 0(sp)
    sw s1, 4(sp)  # value we're looking for
    sw s2, 8(sp)  # pointer to start of current entry
    sw s3, 12(sp) # total entries
    sw s4, 16(sp) # counter
    sw s5, 20(sp) # temp, clobber safe
    mv s1, a0 # save the value we're looking for
    la a0, DICTIONARY_LOCATION
    lw a0, 0(a0) # load the address of the dictionary
    mv s2, a0 # save the address of the dictionary
    call READ_BYTE
    # this byte is how many bytes are in the word seperate
    # codes...
    add s2, s2, a0 # add that to the address of the dictionary
    addi s2, s2, 2 # add 2, one for the byte we just read and one for the entry length byte
    
    mv a0, s2              # Put the address of the 16-bit entry count into a0
    call READ_HALFWORD_BE  # Read the max number of entries (Z-machine memory is always BE)
    mv s3, a0              # Save the total number of entries into s3
    
    # The first actual dictionary entry starts at s2 + 2.
    addi s2, s2, 2
    li s4, 0               # s4 = counter for the loop

loop_dict_lookup:
    # read first half...
    mv a0, s2
    call READ_HALFWORD_BE
    slli s5, a0, 16 # save the first halfword, and shift it
    addi a0, s2, 2 # add 2 to read the second halfword
    call READ_HALFWORD_BE
    mv t0, a0 # save the second halfword
    
    # compare the two halfwords
    or s5, s5, t0 # combine the two halfwords

    # --- DEBUG ---
    mv a0, s5
    li a7, 34
    # ecall
    li a0, ' '
    li a7, 11
    # ecall
    mv a0, s1
    li a7, 34
    # ecall
    li a0, 10
    li a7, 11
    # ecall
    # --- END DEBUG ---

    beq s5, s1, found_word_dict_lookup

    addi s2, s2, 7 # entries are 7 bytes long
    addi s4, s4, 1 # increment counter
    blt s4, s3, loop_dict_lookup # if counter < total entries, keep looping
    li a0, 0 # not found, return 0
    j end_dict_lookup
found_word_dict_lookup:
    # we found the word! now we need to return the (z) address of the word
    la t0, Z_CODE_BASE
    sub a0, s2, t0 # since it's z address, we need to subtract the base address
    j end_dict_lookup
end_dict_lookup:
    lw s5, 20(sp)
    lw s4, 16(sp)
    lw s3, 12(sp)
    lw s2, 8(sp)
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 24
    ret

.globl ASCII_PUNCT_TO_ZSCII
ASCII_PUNCT_TO_ZSCII:
    # a0: ascii value
    # returns the zscii value in a0, -1 = not a punctuation
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s1, 4(sp)

    mv s1, a0 # save the value we're looking for
    # first, let's see if it's in the ranges we're checking for at all... 
    # so between 32 and 63, or 91 through 95
    li t0, 32
    blt s1, t0, not_in_range
    li t0, 96
    bge s1, t0, not_in_range
    li t0, 64
    blt s1, t0, in_range
    li t0, 91
    bge s1, t0, in_range
    j not_in_range
in_range:
    # now, we just decide which range we hit...
    li t0, 64
    blt s1, t0, in_range_1
    li t0, 91
    bge s1, t0, in_range_2
    j not_in_range
in_range_1:
    addi a0, s1, -32 # normalize it as an index into the table...
    la t0, PUNCT_TABLE
    add a0, a0, t0
    call READ_BYTE
    j end
in_range_2:
    addi a0, s1, -91 # normalize it as an index into the table...
    la t0, PUNCT_TABLE_PART_2
    add a0, a0, t0
    call READ_BYTE
    j end
not_in_range:
    li a0, -1
end:
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 8
    ret
    
.globl CHECK_IS_WORD_SEPERATOR
CHECK_IS_WORD_SEPERATOR:
    # a0: ASCII value
    # returns whether it is a word seperator in a0
    addi sp, sp, -20
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
    sw s4, 16(sp)

    mv s1, a0 # save the ASCII value we're looking for
    la a0, DICTIONARY_LOCATION
    lw a0, 0(a0) # load the address of the dictionary
    mv s2, a0 # save the address of the dictionary
    call READ_BYTE
    # this byte is how many bytes are in the word seperate
    # codes...
    addi s2, s2, 1 # add one for the byte we just read
    mv s3, a0 # save the number of bytes
    li s4, 0 # index
index_loop:
    mv a0, s2
    call READ_BYTE
    beq a0, s1, found
    addi s2, s2, 1
    addi s4, s4, 1
    bne s4, s3, index_loop
not_found_sep:
    li a0, 0
    j end_sep
found:
    li a0, 1
end_sep:
    lw s4, 16(sp)
    lw s3, 12(sp)
    lw s2, 8(sp)
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 20
    ret

.globl PARSE_ASCII_STRING
PARSE_ASCII_STRING:
    # a0: hardware address of the text string buffer (byte 0 = size, byte 1.. = text)
    # a1: hardware address of the parse buffer (byte 0 = max tokens, 
    # byte 1 = tokens written, byte 2.. = token data)
    addi sp, sp, -36
    sw ra, 0(sp)
    sw s1, 4(sp)  # text buffer base address
    sw s2, 8(sp)  # parse buffer base address
    sw s3, 12(sp) # text_ptr (current char)
    sw s4, 16(sp) # parse_ptr (current block in buffer)
    sw s5, 20(sp) # max_words
    sw s6, 24(sp) # current_word_count
    sw s7, 28(sp) # start_of_word_ptr
    sw s8, 32(sp) # current_char

    mv s1, a0
    mv s2, a1

    # read max length in tokens from parse buffer byte 0
    mv a0, s2
    call READ_BYTE
    mv s5, a0     # s5 = max_words
    
    # initialize pointers and counters
    addi s3, s1, 1    # text_ptr = string + 1
    addi s4, s2, 2    # parse_ptr = parse_buffer + 2
    li s6, 0          # current_word_count = 0
    mv s7, s3         # start_of_word_ptr = text_ptr

parse_loop:
    # fetch next char
    mv a0, s3
    call READ_BYTE
    mv s8, a0         # s8 = current char

    # check if end of string (ascii is null char or newline or carriage return)
    beq s8, zero, parse_end_of_string
    li t1, 10
    beq s8, t1, parse_end_of_string
    li t1, 13
    beq s8, t1, parse_end_of_string

    # check if space (0x20)
    li t1, 0x20
    beq s8, t1, parse_space

    # check if word separator
    mv a0, s8
    call CHECK_IS_WORD_SEPERATOR
    bne a0, zero, parse_separator

    # normal character, continue word
    addi s3, s3, 1
    j parse_loop

parse_space:
    # space character encountered
    # if we have a word in progress, emit it
    beq s7, s3, parse_space_skip  # if start == current, no word to emit
    call emit_word
parse_space_skip:
    # move past space
    addi s3, s3, 1
    mv s7, s3       # start next word
    j parse_loop

parse_separator:
    # punctuation separator encountered
    # if we have a word in progress before it, emit it
    beq s7, s3, parse_separator_emit
    call emit_word
parse_separator_emit:
    # emit the separator itself as a word
    mv s7, s3       # start of separator word is current char
    addi s3, s3, 1  # end of separator word is next char
    call emit_word
    mv s7, s3       # start next word after separator
    j parse_loop

parse_end_of_string:
    # end of string or buffer
    # emit word if one is in progress
    beq s7, s3, parse_done
    call emit_word

parse_done:
    # write final word count to byte 1 of parse buffer
    mv a0, s2
    addi a0, a0, 1  # byte 1 holds word count
    mv a1, s6       # s6 is current_word_count
    call WRITE_BYTE

    # zorkmid behavior: seed next slot's start-index byte as i+2 at end-of-line.
    # Here s3 points at the terminating 0/CR/LF in the input text buffer.
    # start_index = (s3 - s1) + 1  (1-based position after end)
    # write only if there is another slot available.
    bge s6, s5, parse_done_restore
    slli t0, s6, 2
    add t0, s2, t0
    addi t0, t0, 5   # parse buffer offset for next slot start index
    sub t1, s3, s1
    addi t1, t1, 1
    mv a0, t0
    mv a1, t1
    call WRITE_BYTE

parse_done_restore:
    
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    lw s4, 16(sp)
    lw s5, 20(sp)
    lw s6, 24(sp)
    lw s7, 28(sp)
    lw s8, 32(sp)
    addi sp, sp, 36
    ret

emit_word:
    # local subroutine to emit a word
    # inputs:
    #   s7 = start of word
    #   s3 = end of word (exclusive)
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # if we reached max words, do nothing (just consume)
    bge s6, s5, emit_done
    
    mv a0, s7
    mv a1, s3
    
    # --- DEBUG: Print Word Range ---
    # mv a0, s7
    # la t0, Z_CODE_BASE
    # sub a0, a0, t0
    # li a7, 34
    # ecall
    # li a0, '-'
    # li a7, 11
    # ecall
    # mv a0, s3
    # la t0, Z_CODE_BASE
    # sub a0, a0, t0
    # li a7, 34
    # ecall
    # li a0, 10
    # li a7, 11
    # ecall
    # --- END DEBUG ---

    mv a0, s7      # restore word start ptr for ASCII_TO_ZSCII
    mv a1, s3      # restore word end ptr for ASCII_TO_ZSCII
    call ASCII_TO_ZSCII
    
    # --- DEBUG: Print Encoded ---
    # mv s0, a0 # save encoded
    # mv a0, s0
    # li a7, 34
    # ecall
    # li a0, 10
    # li a7, 11
    # ecall
    # mv a0, s0 # restore
    # --- END DEBUG ---

    call DICTIONARY_LOOKUP
    mv t2, a0         # t2 = dict address
    
    # calculate length of word
    sub t0, s3, s7    # length
    
    # get start index of word relative to string buffer (1-based)
    sub t1, s7, s1    # start_ptr - string_ptr (equals 1-based index)

    # --- ADDED DEBUG: Print Parse Elements ---
    DEBUG_SKIP_IF_DISABLED(t3, t4, emit_word_debug_done)

    addi sp, sp, -12
    sw t0, 0(sp)
    sw t1, 4(sp)
    sw t2, 8(sp)

    li a0, 'R'
    li a7, 11
    ecall
    li a0, 'A'
    ecall
    li a0, 'R'
    ecall
    li a0, 'S'
    ecall
    li a0, ' '
    ecall

    # Print dict addr
    mv a0, t2
    li a7, 34
    ecall
    li a0, ' '
    li a7, 11
    ecall

    # Print length
    mv a0, t0
    li a7, 1
    ecall
    li a0, ' '
    li a7, 11
    ecall

    # Print index
    mv a0, t1
    li a7, 1
    ecall
    li a0, 10
    li a7, 11
    ecall

    lw t0, 0(sp)
    lw t1, 4(sp)
    lw t2, 8(sp)
    addi sp, sp, 12
emit_word_debug_done:
    # --- END ADDED DEBUG ---
    
    # write dictionary address (halfword)
    mv a0, s4
    mv a1, t2
    call WRITE_HALFWORD_BE
    addi s4, s4, 2
    
    # write length (byte)
    sub t0, s3, s7    # length
    mv a0, s4
    mv a1, t0
    call WRITE_BYTE
    addi s4, s4, 1
    
    # write index (byte)
    sub t1, s7, s1    # start_ptr - string_ptr (1-based index)
    mv a0, s4
    mv a1, t1
    call WRITE_BYTE
    addi s4, s4, 1
    
    # increment word count
    addi s6, s6, 1
    
emit_done:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret
