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
test_data_end:
    .word 0xFFFFFFFF

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
expect_data_end:
    .word 0xFFFFFFFF

msg_pass:  .string "OK\n"
msg_fail:  .string "FAIL\n"

.text
main:
    la      t0, test_data       # t0 -> test_data
    la      t1, test_data_end   # t1 -> test_data_end
    la      t2, expect_data     # t2 -> expect data
loop:
    beq     t0, t1, test_pass   # done if no more test cases
    lw      a0, 0(t0)           # load test value
    addi    sp, sp, -16         # 對齊 16 bytes
    sw      t2, 8(sp)
    sw      t1, 4(sp)
    sw      t0, 0(sp)
    jal     bf16_add            # call conversion (a0 is result)
    lw      t2, 0(sp)
    lw      t1, 4(sp)
    lw      t0, 8(sp)
    addi    sp, sp, 16         # 對齊 16 bytes
    lw      t3, 0(t2)           # t3 = expect data
    bne     t3, a0, test_fail
    addi    t0, t0, 4
    addi    t2, t2, 4
    j       loop
test_fail:
    la      a0, msg_fail
    li      a7, 4
    ecall
    j       done
test_pass:
    la      a0, msg_pass
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