############################################################################
# 
# Filename: vga.s
#
# Author: Ethan Hunter
# Class: ECEN 423, Section 1, Winter 2026
# Date: 1/10/2026
#
# Description: provides utility routines for handling the VGA display (80 x 30)
#             for the Z-machine implementation.
#
#
# Functions:
#
#
############################################################################# 

.data
cursor_x: 
    .word 0

# since the first line is the status bar, we start the cursor y at 1
cursor_y: 
    .word 1
vga_base_addr:
    .word 0x8000

.eqv LAST_COLUMN 77			# 79 - last two columns don't show on screen
.eqv LAST_ROW 29			# 31 - last two rows don't show on screen
.eqv COL_NUM_BYTES 4            # each column is 4 bytes
.eqv LAST_COL_LOW 0x4e0        # the low 9 bits of the last column address (0x8000 + 77*4 = 0x84e0, so low 9 bits are 0x4e0)
.eqv GET_COL_MASK 0x1ff        # mask to get the column number from an address (bits 8-0)


.macro get_vga_address (%ret_reg, %scratch_reg)
    la %ret_reg, vga_base_addr
    lw %ret_reg, 0(%ret_reg) # load the base address of the VGA memory (0x8000)
    # shift row reg left 9 as in spec
    la %scratch_reg, cursor_y
    lw %scratch_reg, 0(%scratch_reg) # load the current y position of
    slli %scratch_reg, %scratch_reg, 9 # shift left 9 to get the row offset
    add %ret_reg, %ret_reg, %scratch_reg # add the row offset
    # shift col reg left 2 as in spec
    la %scratch_reg, cursor_x
    lw %scratch_reg, 0(%scratch_reg) # load the current x position
    slli %scratch_reg, %scratch_reg, 2 # shift left 2 to get the column offset
    add %ret_reg, %ret_reg, %scratch_reg # add the column offset
    # restore col reg
.end_macro

.macro vga_addr_of_pos(%col_reg, %row_reg, %ret_reg, %scratch_reg)
    la %ret_reg, vga_base_addr
    lw %ret_reg, 0(%ret_reg) # load the base address of the VGA memory (0x8000)
    # shift row reg left 9 as in spec
    slli %scratch_reg, %row_reg, 9 # shift left 9 to get the row offset
    add %ret_reg, %ret_reg, %scratch_reg # add the row offset
    # shift col reg left 2 as in spec
    slli %scratch_reg, %col_reg, 2 # shift left 2 to get the column offset
    add %ret_reg, %ret_reg, %scratch_reg # add the column offset
.end_macro


.macro vga_addr_of_row(%row_reg, %ret_reg, %scratch_reg)
    la %ret_reg, vga_base_addr
    lw %ret_reg, 0(%ret_reg) # load the base address of the VGA memory (0x8000)
    # shift row reg left 9 as in spec
    slli %scratch_reg, %row_reg, 9 # shift left 9 to get the row offset
    add %ret_reg, %ret_reg, %scratch_reg # add the row offset
.end_macro

.text


.global REDRAW_STATUS
REDRAW_STATUS:
    # the status bar is always on the first line of the screen
    # 


.global NEWLINE
NEWLINE:
    addi sp, sp, -8 # make space on the stack to save the return address
    sw ra, 0(sp) # save the return address
    sw s5, 4(sp) # save s5 since we'll use it as a scratch register

    # is cursor at bottom of screen?
    la t2, cursor_y
    lw t0, 0(t2) # load current y position 
    li t3, LAST_ROW # max row index
    bne t0, t3, not_at_bottom

    # t0: current read row
    # t1: address of start of current read row
    # t2: address of pos in current read row
    # t3: address of pos in current write row
    # t4: scratch
    # t5: max column as addr
    # t6: cols bitmask
    # s5: max row
    li t5, LAST_COL_LOW # max column as address (0x4e0)
    li t6, GET_COL_MASK # bitmask to get column number from address (0x1ff)
    li s5, LAST_ROW # max row index
    
    # load t0 with start of write row.
    li t0, 1 # start of first row (after status bar)
    # calculate address of current write row, but put it in read row... since we
    # copy from read to write, and then recalculate read, at beginning of loop. 
    vga_addr_of_row(t0, t1, t4)
scroll_vert_loop:
    mv t3, t1 # set write row to read row (copying the row)
    addi t0, t0, 1 # increment row index
    vga_addr_of_row(t0, t2, t4) # calculate address of
    mv t1, t2 # save the start addr of current read row (for later)
scroll_horiz_loop:
    lw a0, 0(t2) # load a word from the current read row
    sw a0, 0(t3) # write it to the current write row
    and t4, t2, t6
    beq t4, t5, scroll_horiz_loop_end # if we've reached the last column, end the inner loop
    addi t2, t2, COL_NUM_BYTES # increment read and write addresses by one column (4 bytes)
    addi t3, t3, COL_NUM_BYTES
    j scroll_horiz_loop
scroll_horiz_loop_end:
    bne t0, s5, scroll_vert_loop # if we've reached the last row, end the outer loop
    j reset_x

not_at_bottom:
    # increment y
    la t0, cursor_y
    lw t1, 0(t0) # load current y position
    addi t1, t1, 1
    sw t1, 0(t0) # save the new y position
reset_x:
    la t1, cursor_x
    sw x0, 0(t1) # reset x to 0
    lw ra, 0(sp) # restore ra
    lw s5, 4(sp) # restore s5
    addi sp, sp, 8 # restore the stack pointer
    ret


.global PUT_SCREEN_CHAR_AT
PUT_SCREEN_CHAR_AT:
    # input: a0 = character to print
    j PUT_SCREEN_CHAR
    
.global PUT_SCREEN_CHAR
PUT_SCREEN_CHAR:
    # takes a0 = character to print
    get_vga_address(t0, t1) # get the current VGA address to print to
    sw a0, 0(t0) # write the character to the VGA memory
    la t0, cursor_x
    lw t0, 0(t0) # load the current x position
    li t1, LAST_COLUMN
    bne t0, t1, normal_put_char # if we're at the last column, go to a new line
    addi sp, sp, -4 # make space on the stack to save the return address
    sw ra, 0(sp) # save the return address
    call NEWLINE # call the newline routine to move to the next line
    lw ra, 0(sp) # restore the return address
    addi sp, sp, 4 # restore the stack pointer
    ret
normal_put_char:
    addi t0, t0, 1 # increment x
    la t1, cursor_x
    sw t0, 0(t1) # save the new x position
    ret


    




