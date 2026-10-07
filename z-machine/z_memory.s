############################################################################
# 
# Filename: z_memory.s
#
# Author: Ethan Hunter
# Class: ECEN 423, Section 1, Winter 2026
# Date: 1/10/2026
#
# Description: provides memory and utility routines for byte and halfword reads and writes
#
# Functions:
#   READ_BYTE - reads a byte from memory at the address in a0, returns it in a0
#   READ_HALFWORD_LE - reads a little-endian halfword from memory at the address in a0, returns it in a0
#   READ_HALFWORD_BE - reads a big-endian halfword from memory at the address in a0, returns it in a0
#   HALFWORD_SIGN_EXTEND - sign-extends a halfword in a0 to a full word, returns it in a0
#   WRITE_BYTE - writes a byte to memory at the address in a0, byte to write in a1
#   WRITE_HALFWORD_LE - writes a halfword to memory without swapping bytes at the address in a0, halfword to write in a1
#   WRITE_HALFWORD_BE - writes a halfword to memory after swapping bytes at the address in a0, halfword to write in a1
#   SWAP_32_BIT_ENDIANNESS - swaps the endianness of a 32-bit word in a0, returns it in a0
#
############################################################################# 
.eqv WORD_ALIGN_MASK 0xFFFFFFFC
.global READ_BYTE
READ_BYTE:    
    # Read a byte from memory
    # Input: a0 = address
    # Output: a0 = byte read (zero-extended to 32 bits)
    andi t0, a0, 0x3   # get byte offset within the word
    andi a0, a0, WORD_ALIGN_MASK     # align address to word boundary
    lw a0, 0(a0)        # load the word from memory
    #multiply the byte offset by 8 to get the shift amount
    li t1, 3             # each byte is 8 bits, so shift the byte offset by 3 to multiply by 8
    sll t1, t0, t1      # shift left by bit offset we just calculated, to multiply
    #shift the word to get the byte we want using srl
    srl a0, a0, t1      # shift right by bit offset we just calculated
    andi a0, a0, 0xFF    # mask to get only the byte we want
    ret

# READ_HALFWORD_LE and READ_HALFWORD_BE share code, since the memory access is the same
# it's just whether it gets swapped or not
# Input: a0 = address
# Output: a0 = halfword read (zero-extended to 32 bits)
.global READ_HALFWORD_BE
READ_HALFWORD_BE:
    li t6, 1 # flag to say this is BE at the end 
    j read_halword_start
.global READ_HALFWORD_LE
READ_HALFWORD_LE:
    li t6, 0 # flag to say this is LE at the end
read_halword_start:
    DEBUG_7SEG_REG(sp)
    DEBUG_7SEG_REG(a0)
    # save return address and original address, bc of riscv abi & being nice to meself
    addi sp, sp, -12     # make space on stack
    sw ra, 8(sp)        # save return address
    sw s1, 4(sp)        # save callee saved registers
    sw s2, 0(sp)        
    mv s1, a0           # save original address
    # Read first byte
    jal READ_BYTE       # read the first byte
    mv s2, a0           # move first byte to s2
    mv a0, s1           # restore original address
    # read second byte
    addi a0, a0, 1      # increment address to read second byte
    jal READ_BYTE       # read the second byte
    mv t1, a0           # move second byte to t1
    beq t6, x0, lw_no_swap  # if LE, skip swap
    # Big-endian: swap bytes
    slli t2, s2, 8      # shift first byte to high byte
    or a0, t2, t1       # combine with second byte
    j end_read_halfword
lw_no_swap:
    # Little-endian: no swap
    slli t2, t1, 8      # shift second byte to high byte
    or a0, t2, s2       # combine with first byte
end_read_halfword:
    # restore callee saved registers
    lw s2, 0(sp)        # restore first byte    
    lw s1, 4(sp)        # restore original address
    lw ra, 8(sp)        # restore return address
    addi sp, sp, 12     # restore stack pointer
    ret
.global WRITE_BYTE
WRITE_BYTE:
    # Write a byte to memory
    # Input: a0 = address, a1 = byte to write (lower 8 bits valid)
    andi t0, a0, 0x3    # get byte offset within the word
    slli t0, t0, 3      # multiply byte offset by 8 to get bit offset
    andi t1, a0, WORD_ALIGN_MASK     # align address to word boundary
    lw t2, 0(t1)        # load the word from memory
    # Clear the byte we want to write
    li t3, 0xFF         # load byte mask
    sll t3, t3, t0     # shift mask to correct byte position
    not t3, t3          # invert mask
    and t2, t2, t3      # clear the target byte in the word
    # Prepare the byte to write
    andi a1, a1, 0xFF   # ensure only lower 8 bits are used
    sll a1, a1, t0     # shift byte to correct position
    or t2, t2, a1       # combine with cleared word
    sw t2, 0(t1)        # store the updated word back to memory
    ret

# just like read halfword, but we write instead of read
# we still use flags to double-up our code for BE and LE
# Input: a0 = address, a1 = halfword to write (lower 16 bits valid)
.global WRITE_HALFWORD_BE
WRITE_HALFWORD_BE:
    li t6, 1 # flag to say to write this as BE at the end 
    j write_halfword_start
.global WRITE_HALFWORD_LE
WRITE_HALFWORD_LE:
    li t6, 0 # flag to say to write this as LE at the end
write_halfword_start:
    # save return address and original address
    addi sp, sp, -8     # make space on stack (we won't use the second word until later)
    sw ra, 4(sp)        # save return address
    # extract bytes to write
    andi t0, a1, 0xFF       # get first byte to write
    srli t1, a1, 8           # shift second byte to lower 8 bits
    andi t1, t1, 0xFF       # get second byte to write
    beq t6, x0, write_halfword  # if LE, skip swap
    # Big-endian: swap bytes from internal LE (RISCV) to BE
    mv t2, t0           # move first byte to temporary reg (t2)
    mv t0, t1           # move second byte to first byte
    mv t1, t2           # move temporary reg to second byte
write_halfword:
    # write first byte
    mv a1, t0          # move first byte to a1 for WRITE_BYTE
    sw t1, 0(sp)       # save second byte on stack (WRITE_BYTE will overwrite t1)
    jal WRITE_BYTE     # write first byte
    lw a1, 0(sp)       # load the second byte we saved to stack earlier into the arg
    addi a0, a0, 1     # increment address to write second byte
    jal WRITE_BYTE     # write second byte
    lw ra, 4(sp)       # restore return address
    addi sp, sp, 8     # restore stack pointer
    ret

# this will be a nice function for testing/writing from the z-machine attribute block
.global SWAP_32_BIT_ENDIANNESS
SWAP_32_BIT_ENDIANNESS:
    # Swap the endianness of a 32-bit word in a0
    # Input: a0 = word to swap
    # Output: a0 = word with swapped endianness
    # Extract bytes
    andi t0, a0, 0xFF           # get lowest byte
    srli t1, a0, 8               # shift right to get next byte
    andi t1, t1, 0xFF           # get byte 1 from shifted
    srli t2, a0, 16              # shift right to get byte 2
    andi t2, t2, 0xFF           # get byte 2 from shifted
    srli t3, a0, 24              # shift right to get highest byte
    andi t3, t3, 0xFF           # get byte 3 from shifted
    # Reassemble in swapped order
    slli t0, t0, 24            # move byte 0 to byte 3 position
    slli t1, t1, 16            # move byte 1 to byte 2 position
    slli t2, t2, 8             # move byte 2 to byte 1 position
    or t0, t0, t1
    or t0, t0, t2
    or a0, t0, t3              # combine with byte 3 in byte 0 position
    ret

.global HALFWORD_SIGN_EXTEND
HALFWORD_SIGN_EXTEND:
    # Sign-extend a halfword in a0 to a full word
    # This is for reading signed halfwords from memory (which Z-machine uses a lot)
    # Input: a0 = halfword (lower 16 bits valid)
    # Output: a0 = sign-extended word
    slli t0, a0, 16      # shift left to move sign bit to bit 31
    srai a0, t0, 16      # arithmetic shift right to sign-extend
    ret

