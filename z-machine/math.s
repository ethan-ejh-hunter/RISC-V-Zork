.text
.globl MATH_MUL
.globl MATH_DIV
.globl MATH_MOD

MATH_MUL:
    # a0 = operand 1 (multiplicand/multiplier)
    # a1 = operand 2 (multiplier/multiplicand)
    # returns result in a0
    # we don't have a mul instruction on this... 
    # so software looped multiplication
    # do the shift + add algorithm
    mv t0, x0 # this is our result register
math_mul_do_iteration:
    beq a0, x0, math_mul_end_iteration
    andi t1, a0, 1
    beq t1, zero, math_mul_skip_add
    add t0, t0, a1
math_mul_skip_add:
    slli a1, a1, 1 # shift the mult left by 1 (mult by 2)
    srli a0, a0, 1 # shift the count right by 1 so we examine the next bit
    j math_mul_do_iteration
math_mul_end_iteration:
    mv a0, t0
    ret

MATH_DIV:
    # a0 = numerator, a1 = denominator
    # returns quotient in a0
    # Check for division by zero
    bne a1, zero, math_div_do_div
    ebreak
    j QUIT
math_div_do_div:
    # Sign extend operands from 16 to 32 bits
    slli a0, a0, 16
    srai a0, a0, 16
    slli a1, a1, 16
    srai a1, a1, 16

    # Determine sign of result
    xor t4, a0, a1

    # Absolute value of numerator in a0
    bge a0, zero, math_div_pos_a0
    neg a0, a0
math_div_pos_a0:
    # Absolute value of denominator in a1
    bge a1, zero, math_div_pos_a1
    neg a1, a1
math_div_pos_a1:

    li t0, 0          # quotient
    li t1, 0          # remainder
    li t2, 15         # step counter for 16 bits
math_div_loop:
    slli t1, t1, 1    # Remainder <<= 1
    # Extract bit t2 of numerator
    srl t3, a0, t2
    andi t3, t3, 1
    or t1, t1, t3     # Remainder |= ((Numerator >> i) & 1)

    blt t1, a1, math_div_skip_sub
    sub t1, t1, a1    # Remainder -= Denominator
    li t3, 1
    sll t3, t3, t2
    or t0, t0, t3     # Quotient |= (1 << i)
math_div_skip_sub:
    addi t2, t2, -1
    bge t2, zero, math_div_loop

    # Apply sign to quotient
    bge t4, zero, math_div_pos_res
    neg t0, t0
math_div_pos_res:
    mv a0, t0
    ret

MATH_MOD:
    # a0 = numerator, a1 = denominator
    # returns remainder in a0
    # Check for division by zero
    bne a1, zero, math_mod_do_div
    ebreak
    j QUIT
math_mod_do_div:
    # Sign extend operands from 16 to 32 bits
    slli a0, a0, 16
    srai a0, a0, 16
    slli a1, a1, 16
    srai a1, a1, 16

    # Determine sign of result
    mv t4, a0

    # Absolute value of numerator in a0
    bge a0, zero, math_mod_pos_a0
    neg a0, a0
math_mod_pos_a0:
    # Absolute value of denominator in a1
    bge a1, zero, math_mod_pos_a1
    neg a1, a1
math_mod_pos_a1:

    li t0, 0          # quotient
    li t1, 0          # remainder
    li t2, 15         # step counter for 16 bits
math_mod_loop:
    slli t1, t1, 1    # Remainder <<= 1
    # Extract bit t2 of numerator
    srl t3, a0, t2
    andi t3, t3, 1
    or t1, t1, t3     # Remainder |= ((Numerator >> i) & 1)

    blt t1, a1, math_mod_skip_sub
    sub t1, t1, a1    # Remainder -= Denominator
    li t3, 1
    sll t3, t3, t2
    or t0, t0, t3     # Quotient |= (1 << i)
math_mod_skip_sub:
    addi t2, t2, -1
    bge t2, zero, math_mod_loop

    # Apply sign to remainder
    bge t4, zero, math_mod_pos_res
    neg t1, t1
math_mod_pos_res:
    mv a0, t1
    ret
