.equ BF16_SIGN_MASK , 0x00008000
.equ BF16_EXP_MASK  , 0x00007F80    #[14:0]
.equ BF16_MANT_MASK , 0x0000007F    #[6:0]
.equ BF16_EXP_BIAS  , 127
.equ BF16_POS_INF   , 0x00007F80
.equ BF16_NEG_INF   , 0x0000FF80
.equ BF16_NAN       , 0x00007FC0
.equ BF16_ZERO      , 0x00000000
.equ BF16_BITS      , 0x00007FFF

.data
test_a_data:
    .word 0x00000000    # +0.0
    .word 0x00008000    # -0.0
    .word 0x00008000    # -0.0
    .word 0x00000000    # +0.0
    .word 0x00007F80    # +inf
    .word 0x0000FF80    # -inf
    .word 0x00007FC0    # NaN
    .word 0x00003F80    # 1.0
    .word 0x0000BF80    # -1.0
    .word 0x00000000    # +0.0
    .word 0x00000000    # +0.0
    .word 0x0000BF80    # -1.0
    .word 0x00003F81    # +1.0078125
    .word 0x0000BF82    # -1.015625
    .word 0x0000BF81    # -1.0078125
test_a_data_end:
    .word 0xFFFFFFFF

test_b_data:
    .word 0x00000000    # +0.0
    .word 0x00008000    # -0.0
    .word 0x00000000    # +0.0
    .word 0x00008000    # -0.0
    .word 0x00007F80    # +inf
    .word 0x0000FF80    # -inf
    .word 0x00007FC0    # NaN
    .word 0x00000000    # +0.0
    .word 0x00000000    # +0.0
    .word 0x00003F80    # 1.0
    .word 0x0000BF80    # -1.0
    .word 0x00003F80    # 1.0
    .word 0x00003F81    # +1.0078125
    .word 0x0000BF82    # -1.015625
    .word 0x0000BF81    # -1.0078125

expect_add_data:
    .word 0x00000000    # +0.0
    .word 0x00008000    # -0.0
    .word 0x00000000    # +0.0
    .word 0x00000000    # +0.0
    .word 0x00007F80    # +inf
    .word 0x0000FF80    # -inf
    .word 0x00007FC0    # NaN
    .word 0x00003F80    # 1.0
    .word 0x0000BF80    # -1.0
    .word 0x00003F80    # 1.0
    .word 0x0000BF80    # -1.0
    .word 0x00000000    # +0.0
    .word 0x00004001    # +2.015625
    .word 0x0000C002    # -2.03125
    .word 0x0000C001    # -2.015625

expect_sub_data:
    .word 0x00000000    # +0.0
    .word 0x00000000    # +0.0
    .word 0x00008000    # -0.0
    .word 0x00000000    # +0.0
    .word 0x00007FC0    # NaN
    .word 0x00007FC0    # NaN
    .word 0x00007FC0    # NaN
    .word 0x00003F80    # 1.0
    .word 0x0000BF80    # -1.0
    .word 0x0000BF80    # -1.0
    .word 0x00003F80    # 1.0
    .word 0x0000C000    # -2.0
    .word 0x00000000    # +0.0
    .word 0x00000000    # +0.0
    .word 0x00000000    # +0.0

msg_a:  .string "a: "
msg_b:  .string " b: "
msg_expect_add:  .string " expect add: "
msg_actual_add:  .string " actual add: "
msg_next:  .string " \n"
msg_all_pass:  .string "ALL PASS\n"
msg_fail:  .string "FAIL\n"

.text
main:
    la      t0, test_a_data     # t0 -> test_a_data
    la      t1, test_a_data_end # t1 -> test_a_data_end
    la      t2, test_b_data     # t2 -> test_b_data
    la      t3, expect_add_data # t3 -> expect_add_data
    la      t4, expect_sub_data # t4 -> expect_sub_data
loop:
    beq     t0, t1, test_pass   # done if no more test cases
#display message start
    la      a0, msg_a
    li      a7, 4
    ecall
    lw      a0, 0(t0)           #
    li      a7, 34
    ecall
    la      a0, msg_b
    li      a7, 4
    ecall
    lw      a0, 0(t2)           # 
    li      a7, 34
    ecall
    la      a0, msg_expect_add
    li      a7, 4
    ecall
    lw      a0, 0(t3)           # 
    li      a7, 34
    ecall
    la      a0, msg_actual_add
    li      a7, 4
    ecall
#display message end
    lw      a0, 0(t0)           # load bf16 a test value
    lw      a1, 0(t2)           # load bf16 b test value
    addi    sp, sp, -16         # align 16 bytes
    sw      t4, 16(sp)
    sw      t3, 12(sp)
    sw      t2, 8(sp)
    sw      t1, 4(sp)
    sw      t0, 0(sp)
    jal     bf16_add            # call conversion (a0 is result)
    lw      t0, 0(sp)
    lw      t1, 4(sp)
    lw      t2, 8(sp)
    lw      t3, 12(sp)
    lw      t4, 16(sp)
    addi    sp, sp, 16          # align 16 bytes
    lw      t5, 0(t3)           # t5 = expect data
    mv      a1, a0              # save return value in a1
#display actual start
    li      a7, 34
    ecall
    la      a0, msg_next
    li      a7, 4
    ecall
#display actual end
    mv      a0, a1             # restore value from a1
    bne     t5, a0, test_fail
    addi    t0, t0, 4
    addi    t2, t2, 4
    addi    t3, t3, 4
    addi    t4, t4, 4
    j       loop
test_fail:
    la      a0, msg_fail
    li      a7, 4
    ecall
    j       done
test_pass:
    la      a0, msg_all_pass
    li      a7, 4
    ecall
done:
    li      a7, 10
    ecall

# bf16_sub
# | variable       | Reg   |
# | -------------- | ----- |
# | a.bits/result  | a0    |
# | b.bits/xor_b   | a1    |
bf16_sub:
    li      t0, BF16_SIGN_MASK
    xor     a1, a1, t0          # b.bits ^= BF16_SIGN_MASK
    jal     bf16_add            # a0 = bf16_add(a0, a1)
    ret
# bf16_add
# | variable       | Reg   |
# | -------------- | ----- |
# | a.bits/result  | a0    |
# | b.bits         | a1    |
# | sign_a         | s0    |
# | sign_b         | s1    |
# | exp_a          | s2    |
# | exp_b          | s3    |
# | mant_a         | s4    |
# | mant_b         | s5    |
# | exp_diff       | s6    |
# | const.imm 0xFF | s7    |
# | const.imm 8    | s8    |
# | const.imm -8   | s9    |
# | const.imm 0x100| s10   |
# | result_sign    | t0    |
# | result_exp     | t1    |
# | result_mant    | t2    |

bf16_add:
    # sign_a = (a.bits >> 15) & 1
    srli    s0, a0, 15
    andi    s0, s0, 1

    # sign_b = (b.bits >> 15) & 1
    srli    s1, a1, 15
    andi    s1, s1, 1

    # exp_a = (a.bits >> 7) & 0xFF
    srli    s2, a0, 7
    andi    s2, s2, 0xFF

    # exp_b = (b.bits >> 7) & 0xFF
    srli    s3, a1, 7
    andi    s3, s3, 0xFF

    # mant_a = a.bits & 0x7F
    andi    s4, a0, 0x7F

    # mant_b = b.bits & 0x7F
    andi    s5, a1, 0x7F

    li      s7, 0xFF
check_a_inf:
    #// if (exp_a == 0xFF)
    bne     s2, s7, check_b_inf
    # mant_a != 0 ? return a0
    beqz    s4, check_b_inf_nan
    ret

check_b_inf_nan:
    #// if (exp_b == 0xFF)
    beq     s3, s7, both_inf_check
    ret

both_inf_check:
    #// if (mant_b || sign_a == sign_b)
    bnez    s5, return_b
    beq     s0, s1, return_b
    # return BF16_NAN (0x7FC0)
    li      a0, BF16_NAN
    ret

return_b:
    mv      a0, a1
    ret

return_BF16_ZERO:
    li      a0, BF16_ZERO
    ret

check_b_inf:
    #// if (exp_b == 0xFF)
    beq     s3, s7, return_b

check_a_zero:
    bnez    s2, check_b_zero
    bnez    s4, check_b_zero
    bnez    s3, return_b
    bnez    s5, return_b
    bne     s0, s1, return_BF16_ZERO
    ret     # return a

check_b_zero:
    bnez    s3, check_exp_a
    bnez    s5, check_exp_a
    ret     # returna a

check_exp_a:
    beqz    s2, check_exp_b
    ori     s4, s4, 0x80

check_exp_b:
    beqz    s3, skip_exp_b
    ori     s5, s5, 0x80

skip_exp_b:
    sub     s6, s2, s3
    ret
