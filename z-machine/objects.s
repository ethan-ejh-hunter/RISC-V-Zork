############################################################################
# 
# Filename: objects.s
#
# Author: Ethan Hunter
# Class: ECEN 423, Section 1, Winter 2026
# Date: 1/25/2026
#
# Description: provides utility routines for handling Z-machine objects. 
# Note that as in all other functions, any "address" is the address in 
# the RISC-V machine's memory space, unless otherwise specified.
#
# Routines:
# GET_OBJECT_ADDRESS - gets the address of an object in memory
# GET_OBJECT_PROPERTY_ADDRESS - gets the address of an object's property table
# GET_OBJECT_RELATION - gets the parent, sibling, or child of an object, based on the offset
# SET_OBJECT_RELATION - sets the parent, sibling, or child of an object, based on the offset
# REMOVE_OBJECT_FROM_TREE - removes an object from the tree
# ADD_OBJECT_TO_TREE - adds an object to the tree at a specific location
# CHECK_OBJECT_ATTRIBUTE - checks if an object has a specific attribute
# SET_OBJECT_ATTRIBUTE - sets an object's attribute
# CLEAR_OBJECT_ATTRIBUTE - clears an object's attribute
# MODIFY_OBJECT_ATTRIBUTE - modifies an object's attribute
# GET_OBJECT_ATTRIBUTE - gets an object's attribute flags
# SET_OBJECT_PROPERTY
# GET_OBJECT_PROPERTY
#
############################################################################# 
.text

.globl GET_OBJECT_ADDRESS
# note that this address points to the attribute flags (so no specific routine for it)
# Inputs:
#   a0 - object number (0-255)
# Outputs:
#   a0 - address of object in memory
GET_OBJECT_ADDRESS:
    # so objects are 1-indexed, but we want 0-indexed
    addi a0, a0, -1
    la t0, OBJECT_TABLE_LOCATION
    lw t0, 0(t0)
    # now we do a multiplication by 9
    # which we will do by adding 8*a0 + a0
    slli t1, a0, 3 # t1 = 8*a0
    add a0, a0, t1 # a0 = 9*a0
    add a0, a0, t0 # a0 = object table address + 9*a0
    ret

.globl GET_OBJECT_RELATION
# Inputs:
#   a0 - address of object in memory
#   a1 - offset of the relation in the object table (0x04 for parent, 0x05 for sibling, 0x06 for child)
# Outputs:
#   a0 - parent of object (as the number, not the address)
GET_OBJECT_RELATION:
    # save the return pointer...
    addi sp, sp, -4
    sw ra, 0(sp)
    add a0, a0, a1 # move to selected relation field
    call READ_BYTE
    # now a0 has the relation, so restore the return pointer and return
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

.globl SET_OBJECT_RELATION
# Inputs:
#   a0 - address of object in memory
#   a1 - offset of the relation in the object table (0x04 for parent, 0x05 for sibling, 0x06 for child)
#   a2 - object id of object to make it related to. 
SET_OBJECT_RELATION:
    # save the return pointer...
    addi sp, sp, -4
    sw ra, 0(sp)
    add a0, a0, a1 # move to selected relation field
    mv a1, a2
    call WRITE_BYTE
    # now a0 has the relation, so restore the return pointer and return
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

.globl REMOVE_OBJECT_FROM_TREE
# Inputs:
#   a0 - id of object to remove from tree
REMOVE_OBJECT_FROM_TREE:
    # save the return pointer and s1, s2, s3, s4
    addi sp, sp, -20
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
    sw s4, 16(sp)
    mv s1, a0 # save our object id
    call GET_OBJECT_ADDRESS
    mv s4, a0 # save our object address
    # check if we have a parent
    li a1, PARENT_OFFSET
    call GET_OBJECT_RELATION
    # do we have a parent
    bne a0, zero remove_obj_has_parent
    # we don't have a parent, so we're the root of the tree, or just 
    # not spawned yet or something...
    # so just return
    j remove_obj_done
remove_obj_has_parent:
    # we have a parent, so we need to remove ourselves from its child list
    # check if we're the first item in the children linked list
    # start by getting parent object address...
    mv s2, a0 # save parent id number
    call GET_OBJECT_ADDRESS
    # are we the parent's listed child?
    # save parent address
    mv s3, a0
    # get child
    li a1, CHILD_OFFSET
    call GET_OBJECT_RELATION
    bne a0, s1, remove_obj_not_first_child
    # we are the first child, so we need to set the parent's child to our sibling
    mv a0, s4 # grab our address
    li a1, SIBLING_OFFSET
    call GET_OBJECT_RELATION
    # now we need to set the parent's child to our sibling
    mv a2, a0 # grab our sibling id
    mv a0, s3 # grab our parent address
    li a1, CHILD_OFFSET
    call SET_OBJECT_RELATION
    j remove_obj_done
remove_obj_not_first_child:
    # we're not the first child, so we need to find the previous sibling...
    # currently the sibling id is in a0
sibling_loop:
    # lookup sibling
    call GET_OBJECT_ADDRESS # get the sibling address in a0
    li a1, SIBLING_OFFSET 
    mv s3, a0 # save sibling address on top of the (unneeded) parent address
    call GET_OBJECT_RELATION # now see what the sibling's sibling is
    bne a0, s1, sibling_loop # did we find ourself?
    # we found ourself, so we need to set the sibling's sibling to our sibling
    # get our sibling id
    mv a0, s4 # grab our address
    li a1, SIBLING_OFFSET
    call GET_OBJECT_RELATION
    mv a2, a0 # save id of the sibling behind us
    mv a0, s3 # grab the address of the sibling in front of us
    li a1, SIBLING_OFFSET
    # set sibling in front of us's next sibling to the sibling behind us
    call SET_OBJECT_RELATION 
remove_obj_done:
    # now, remove our sibling...
    mv a0, s4 # grab our address
    li a1, SIBLING_OFFSET
    li a2, 0 # clear our relationship to the sibling
    call SET_OBJECT_RELATION
    # finally, remove our parent...
    mv a0, s4 # grab our address
    li a1, PARENT_OFFSET
    li a2, 0 # clear our relationship to the parent
    call SET_OBJECT_RELATION
    # restore the return pointer and s1-s4
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    lw s4, 16(sp)
    addi sp, sp, 20
    ret

.globl INSERT_OBJECT_INTO_TREE
# Inputs:
#   a0 - ID of object to insert into tree
#   a1 - ID of parent object
INSERT_OBJECT_INTO_TREE:
    # save the return pointer and s1-s5
    addi sp, sp, -24
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
    sw s4, 16(sp)
    sw s5, 20(sp)

    # save the object id and parent id
    mv s1, a0 # save object id to insert
    mv s2, a1 # save parent id

    # Remove it from it's current position...
    mv a0, s1
    call REMOVE_OBJECT_FROM_TREE

    # get parent address
    mv a0, s2 # grab parent id
    call GET_OBJECT_ADDRESS
    mv s4, a0 # save parent address
    # get parent's child
    li a1, CHILD_OFFSET
    call GET_OBJECT_RELATION
    mv s3, a0 # save new parent's current child
    # add that as our sibling
    mv a0, s1 # grab our id
    call GET_OBJECT_ADDRESS
    mv s5, a0 # save our address
    li a1, SIBLING_OFFSET
    mv a2, s3 # grab our new sibling's id (may be zero)
    call SET_OBJECT_RELATION
    # now add our new parent
    mv a0, s5 # grab our address
    li a1, PARENT_OFFSET
    mv a2, s2 # grab our new parent's id
    call SET_OBJECT_RELATION
    # finally, add ourselves as the new parent's child
    mv a0, s4 # grab our new parent's address
    li a1, CHILD_OFFSET
    mv a2, s1 # grab our id
    call SET_OBJECT_RELATION
    # restore the return pointer and s1-s4
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    lw s4, 16(sp)
    lw s5, 20(sp)
    addi sp, sp, 24
    ret

.globl ADD_OBJECT_TO_TREE
# Inputs:
#   a0 - address of object in memory
#   a1 - offset of the relation in the object table (0x04 for parent, 0x05 for sibling, 0x06 for child)
#   a2 - object id of object to make it related to. 
ADD_OBJECT_TO_TREE:
    # save the return pointer...
    addi sp, sp, -4
    sw ra, 0(sp)
    add a0, a0, a1 # move to selected relation field
    mv a0, a2
    call WRITE_BYTE
    # now a0 has the relation, so restore the return pointer and return
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

.globl GET_OBJECT_PROPERTY_ADDRESS
# Inputs:
#   a0 - address of object in memory
# Outputs:
#   a0 - address of object's property table
GET_OBJECT_PROPERTY_ADDRESS:
    # save the return pointer...
    addi sp, sp, -4
    sw ra, 0(sp)
    addi a0, a0, 7 # move to property table address field
    call READ_HALFWORD_BE
    # now a0 has the property table address
    la t0, Z_CODE_BASE
    add a0, a0, t0
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

.globl CHECK_OBJECT_ATTRIBUTE
# Inputs:
#   a0 - address of object in memory
#   a1 - attribute to check (0-31)
# Outputs:
#   a0 - 1 if attribute is set, 0 otherwise
CHECK_OBJECT_ATTRIBUTE:
    # save the return pointer and s1
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s1, 4(sp)
    # decide what byte we need...
    srli t0, a1, 3 # divide it by 8
    # save the attribute number
    mv s1, a1
    # add the offset to the address
    add a0, a0, t0
    call READ_BYTE
    # now, get the bit we want... keep in mind attribute 0 is the MSB of first byte
    # so get lower 3 bits of attribute number
    andi t0, s1, 0x7
    # we want to subtract that number from 7 to get the shift amount
    li t1, 7
    sub t0, t1, t0
    # shift the byte to get the bit we want in the rightmost position
    srl a0, a0, t0
    # mask to get only the bit we want
    li t0, 1
    # store it in a0
    and a0, a0, t0
    # restore the return pointer and s1
    lw ra, 0(sp)
    lw s1, 4(sp)
    addi sp, sp, 8
    ret


.globl SET_OBJECT_ATTRIBUTE
# inputs: 
#   a0 - address of object in memory
#   a1 - attribute to set (0-31)
SET_OBJECT_ATTRIBUTE:
    li a2, 1
    j MODIFY_OBJECT_ATTRIBUTE
.globl CLEAR_OBJECT_ATTRIBUTE
# inputs: 
#   a0 - address of object in memory
#   a1 - attribute to clear (0-31)
CLEAR_OBJECT_ATTRIBUTE:
    li a2, 0
    j MODIFY_OBJECT_ATTRIBUTE
.globl MODIFY_OBJECT_ATTRIBUTE
# inputs: 
#   a0 - address of object in memory
#   a1 - attribute to set (0-31)
#   a2 - value to set (0 or 1)
MODIFY_OBJECT_ATTRIBUTE:
    # save return pointer, s1, s2, s3
    addi sp, sp, -16
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
    # decide what byte we need...
    srli t0, a1, 3 # divide it by 8
    # save the attribute number
    mv s1, a1
    # save the value to set
    mv s3, a2
    # add the offset to the address
    add a0, a0, t0
    mv s2, a0 # save the address of the byte we read
    call READ_BYTE
    # create the bitmask we'll be using
    li t0, 1
    # subtract the lower 3 bits of the attribute number from 7 to get the shift amount
    andi t2, s1, 0x7   # get bit index within the byte (0-7)
    li t1, 7
    sub t2, t1, t2     # shift = 7 - (attr & 7), so attr 0 => bit 7, attr 7 => bit 0
    # now shift the bitmask to the correct position
    sll t0, t0, t2
    # if we're setting, we need to OR; if we're clearing, we need AND-NOT
    beq s3, x0, clear_attribute
    # set attribute, save to the arg register that is used for the write
    or a1, a0, t0
    j end_modify_attribute
clear_attribute:
    # clear attribute: invert the mask, then AND with the current byte
    xori t0, t0, -1    # bitwise NOT of the mask
    and a1, a0, t0
end_modify_attribute:
    # write the byte back
    mv a0, s2
    call WRITE_BYTE
    # restore the return pointer and s1, s2, s3
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    addi sp, sp, 16
    ret
.global GET_OBJECT_ADDRESS_OF_SPECIFIC_PROPERTY
GET_OBJECT_ADDRESS_OF_SPECIFIC_PROPERTY:
# inputs: 
#   a0 - address of object in memory
#   a1 - property number (1-31)
# outputs:
#   a0 - address of property value
    addi sp, sp, -16
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
    # save arguments
    mv s1, a0
    mv s2, a1

    # now, lookup the object property table address
    call GET_OBJECT_PROPERTY_ADDRESS
    mv s3, a0 # save the address of the property table
    addi s3, s3, 1 # add 1 to get to the first byte of string
    # that address is pointing to the length of the 
    # first property, or the name of the object
    call READ_BYTE
    slli t0, a0, 1 # multiply by 2 (since length is in words)
    add s3, s3, t0 # add the length to the property table address to get to the first property
object_property_loop:
    # read prop lenght/id byte
    mv a0, s3
    call READ_BYTE
    # extract ID

    # ID is lower 5 bytes, 
    # | SIZE  | ID           |
    # 7  6  5  4  3  2  1  0
    # 0xe0     0x1f
    andi t0, a0, 0x1f # mask out the size to get ID
    # does it equal the property we're looking for?
    beq t0, s2, found_property
    # is it less than the property we're looking for?
    blt t0, s2, prop_not_found
    # is it straight up 0?
    beq t0, x0, prop_not_found
    # if not, keep looking
    # we need to get the length of this property
    andi t0, a0, 0xe0 # mask out the id to get size bits
    srli t0, t0, 5    # shift right by 5 to get the size
    addi t0, t0, 2    # add 2... 1 to get past header, one since it's stored as 
    # length - 1
    add s3, s3, t0 # move pointer to next property
    j object_property_loop

found_property:
    # we found the property! return s3 (length + id byte)
    mv a0, s3
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    addi sp, sp, 16
    ret

prop_not_found:
    # we didn't find the property, return 0
    li a0, 0
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    addi sp, sp, 16
    ret


.globl SET_OBJECT_PROPERTY
# inputs: a0 - address of object in memory
#         a1 - property number (1-31)
#         a2 - value to set
SET_OBJECT_PROPERTY:
    # technically, undefined to have a length of greater than 2 bytes...
    # either write 1 byte or a halfword

    # save return pointer, s1
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)

    mv s1, a2
    call GET_OBJECT_ADDRESS_OF_SPECIFIC_PROPERTY
    # a0 now has the address of the property's id/length
    # ID is upper 3 bytes, 
    # | ID    | LENGTH       |
    # 7  6  5  4  3  2  1  0
    # 0xe0     0x1f
    mv s2, a0
    call READ_BYTE
    mv t1, a0
    addi a0, s2, 1 # add 1 to the property address
    mv a1, s1 # move the value to set to a1
    li t0, 0xe0
    and t1, t1, t0 # mask out the id to get the size
    beq zero, t1, set_one_byte_property
set_two_byte_property:
    # now, write the value to the property
    call WRITE_HALFWORD_BE
    j end_set_object_property
set_one_byte_property:
    call WRITE_BYTE
end_set_object_property:
    # restore the return pointer and s1
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret
.globl GET_OBJECT_PROPERTY
# inputs: a0 - address of object in memory
#         a1 - property number (1-31)
# outputs: a0 - value of property
GET_OBJECT_PROPERTY:
    # save return pointer, s1
    addi sp, sp, -12
    sw ra, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)

    mv s1, a1
    call GET_OBJECT_ADDRESS_OF_SPECIFIC_PROPERTY
    mv s2, a0
    beq s2, zero, get_default_property
    call READ_BYTE
    mv t1, a0
    addi s2, s2, 1 # add 1 to the property address
    li t0, 0xe0
    and t1, t1, t0 # mask out the id to get the size
    beq zero, t1, get_one_byte_property
get_two_byte_property:
    # now, read the value from the property
    mv a0, s2
    call READ_HALFWORD_BE
    j end_get_object_property
get_one_byte_property:
    mv a0, s2
    call READ_BYTE
    j end_get_object_property
get_default_property:
    # Property not found in object, fetch from default property table
    la t0, PROPERTY_DEFAULTS_TABLE_LOCATION
    lw t0, 0(t0)
    # the requested property number is in s1 (1-31)
    # each default property is a 2-byte word. Property 1 is at index 0
    addi s1, s1, -1
    slli s1, s1, 1 # multiply by 2
    add a0, t0, s1 # add offset to table base
    call READ_HALFWORD_BE
end_get_object_property:
    # restore the return pointer and s1
    lw ra, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    addi sp, sp, 12
    ret


    




    

    
    
    
    
    
    