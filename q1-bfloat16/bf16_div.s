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
    .word 0x00007FC0  # 1. NaN
    .word 0x00003F80  # 2. ÷ NaN
    .word 0x00007F80  # 11. +Inf ÷ +Inf
    .word 0x00003F80  # 6. ÷ +Inf
    .word 0x00000000  # 12. 0 ÷ 0
    .word 0x00003F80  # 3. ÷ 0
    .word 0x00000000  # 4. 0 ÷ 1
    .word 0x00007F80  # 5. +Inf ÷ 1
    .word 0x00000080  # 7. subnormal ÷ normal
    .word 0x00003E80  # 8. triggers normalization
    .word 0x00000040  # 9. exp_a == 0
    .word 0x00003F80  # 10. result_exp++ (exp_b == 0)
test_a_data_end:
    .word 0xFFFFFFFF

test_b_data:
    .word 0x00003F80  # 1. normal
    .word 0x00007FC0  # 2. NaN
    .word 0x00007F80  # 11. +Inf
    .word 0x00007F80  # 6. +Inf
    .word 0x00000000  # 12. zero
    .word 0x00000000  # 3. zero
    .word 0x00003F80  # 4. normal
    .word 0x00003F80  # 5. normal
    .word 0x00003F80  # 7. normal
    .word 0x00003F81  # 8. subnormal to trigger normalization
    .word 0x00003F80  # 9. normal
    .word 0x00000040  # 10. exp zero

expect_div_data:
    .word 0x00007FC0  # 1.
    .word 0x00007FC0  # 2.
    .word 0x00007FC0  # 11.
    .word 0x00000000  # 6.
    .word 0x00007FC0  # 12.
    .word 0x00007F80  # 3.
    .word 0x00000000  # 4.
    .word 0x00007F80  # 5.
    .word 0x00000080  # 7.
    .word 0x00003E7E  # 8.
    .word 0x00000000  # 9.
    .word 0x00007F80  # 10.

msg_a:  .string "a: "
msg_b:  .string " b: "
msg_expect_div:  .string " expect div: "
msg_actual_div:  .string " actual div: "
msg_next:  .string " \n"
msg_all_pass:  .string "ALL PASS\n"
msg_fail:  .string "FAIL\n"

.text
main:
    la      t0, test_a_data     # t0 -> test_a_data
    la      t1, test_a_data_end # t1 -> test_a_data_end
    la      t2, test_b_data     # t2 -> test_b_data
    la      t3, expect_div_data # t3 -> expect_div_data
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
    la      a0, msg_expect_div
    li      a7, 4
    ecall
    lw      a0, 0(t3)           #
    li      a7, 34
    ecall
#display message end
    lw      a0, 0(t0)           # load bf16 a test value
    lw      a1, 0(t2)           # load bf16 b test value
    addi    sp, sp, -16         # align 16 bytes
    sw      t3, 12(sp)
    sw      t2, 8(sp)
    sw      t1, 4(sp)
    sw      t0, 0(sp)
    jal     bf16_div            # call conversion (a0 is result)
    lw      t0, 0(sp)
    lw      t1, 4(sp)
    lw      t2, 8(sp)
    lw      t3, 12(sp)
    addi    sp, sp, 16          # align 16 bytes
    mv      a2, a0              # save return value in a2

#display actual start
    la      a0, msg_actual_div
    li      a7, 4
    ecall
    mv      a0, a2             # display bf16_div acutal
    li      a7, 34
    ecall
    la      a0, msg_next
    li      a7, 4
    ecall
#display actual end
    lw      t5, 0(t3)          # t5 = expect sub data
    bne     t5, a2, test_fail  # check expect add data != actual add data
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

# bf16_div
# | variable                | Reg   |
# | ----------------------- | ----- |
# | a.bits/result           | a0    |
# | b.bits                  | a1    |
# | sign_a                  | s0    |
# | sign_b                  | s1    |
# | exp_a                   | s2    |
# | exp_b                   | s3    |
# | mant_a                  | s4    |
# | mant_b                  | s5    |
# | const.imm BF16_POS_INF  | s6    |
# | const.imm 0xFF          | s7    |
# | const.imm 0x8000 [15:0] | s8    |
# | const.imm 16            | s10   |
# | result_sign             | t0    |
# | result_exp              | t1    |
# | result_mant             | t2    |

bf16_div:
    ret