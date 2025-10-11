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
    .word 0x00000000    # 1. +0 vs +0
    .word 0x00008000    # 2. -0 vs +0
    .word 0x00003F80    # 3. +1 vs +1
    .word 0x00003F80    # 4. +1 vs +2
    .word 0x00004000    # 5. +2 vs +1
    .word 0x00003F80    # 6. +1 vs -1
    .word 0x0000C000    # 7. -2 vs -1
    .word 0x0000BF80    # 8. -1 vs -2
    .word BF16_POS_INF  # 9. +Inf vs +Inf
    .word BF16_POS_INF  # 10. +Inf vs -Inf
    .word BF16_NEG_INF  # 11. -Inf vs +Inf
    .word BF16_NAN      # 12. NaN vs +1.0
    .word 0x00003F80    # 13. +1.0 vs NaN

test_a_data_end:
    .word 0xFFFFFFFF

test_b_data:
    .word 0x00000000    # 1. +0 vs +0
    .word 0x00000000    # 2. -0 vs +0
    .word 0x00003F80    # 3. +1 vs +1
    .word 0x00004000    # 4. +1 vs +2
    .word 0x00003F80    # 5. +2 vs +1
    .word 0x0000BF80    # 6. +1 vs -1
    .word 0x0000BF80    # 7. -2 vs -1
    .word 0x0000C000    # 8. -1 vs -2
    .word BF16_POS_INF  # 9. +Inf vs +Inf
    .word BF16_NEG_INF  # 10. +Inf vs -Inf
    .word BF16_POS_INF  # 11. -Inf vs +Inf
    .word 0x00003F80    # 12. NaN vs +1.0
    .word BF16_NAN      # 13. +1.0 vs NaN

expect_eq_data:
    .word 1     # 1. +0 == +0
    .word 1     # 2. -0 == +0
    .word 1     # 3. +1 == +1
    .word 0     # 4. +1 != +2
    .word 0     # 5. +2 != +1
    .word 0     # 6. +1 != -1
    .word 0     # 7. -2 != -1
    .word 0     # 8. -1 != -2
    .word 1     # 9. +Inf == +Inf
    .word 0     # 10. +Inf != -Inf
    .word 0     # 11. -Inf != +Inf
    .word 0     # 12. NaN != +1.0
    .word 0     # 13. +1.0 vs NaN

expect_lt_data:
    .word 0     # 1. +0 < +0
    .word 0     # 2. -0 < +0 (treated equal)
    .word 0     # 3. +1 < +1
    .word 1     # 4. +1 < +2
    .word 0     # 5. +2 < +1
    .word 0     # 6. +1 < -1
    .word 1     # 7. -2 < -1
    .word 0     # 8. -1 < -2
    .word 0     # 9. +Inf < +Inf
    .word 0     # 10. +Inf < -Inf
    .word 1     # 11. -Inf < +Inf
    .word 0     # 12. NaN < +1.0
    .word 0     # 13. +1.0 vs NaN

expect_gt_data:
    .word 0     # 1. +0 > +0
    .word 0     # 2. -0 > +0
    .word 0     # 3. +1 > +1
    .word 0     # 4. +1 > +2
    .word 1     # 5. +2 > +1
    .word 1     # 6. +1 > -1
    .word 0     # 7. -2 > -1
    .word 1     # 8. -1 > -2
    .word 0     # 9. +Inf > +Inf
    .word 1     # 10. +Inf > -Inf
    .word 0     # 11. -Inf > +Inf
    .word 0     # 12. NaN > +1.0
    .word 0     # 13. +1.0 vs NaN

msg_a:  .string "a: "
msg_b:  .string " b: "
msg_expect_eq:  .string " expect eq: "
msg_expect_lt:  .string " expect lt: "
msg_expect_gt:  .string " expect gt: "
msg_actual_eq:  .string " actual eq: "
msg_actual_lt:  .string " actual lt: "
msg_actual_gt:  .string " actual gt: "
msg_next:  .string " \n"
msg_all_pass:  .string "ALL PASS\n"
msg_fail:  .string " FAIL\n"

.text
main:
    la      t0, test_a_data     # t0 -> test_a_data
    la      t1, test_a_data_end # t1 -> test_a_data_end
    la      t2, test_b_data     # t2 -> test_b_data
    la      t3, expect_eq_data  # t3 -> expect_eq_data
    la      t4, expect_lt_data  # t4 -> expect_lt_data
    la      t5, expect_gt_data  # t4 -> expect_gt_data
loop:
    beq     t0, t1, test_pass   # done if no more test cases
#display message start
    la      a0, msg_a
    li      a7, 4
    ecall
    lw      a0, 0(t0)           # test_a_data
    li      a7, 34
    ecall
    la      a0, msg_b
    li      a7, 4
    ecall
    lw      a0, 0(t2)           # test_b_data
    li      a7, 34
    ecall
    la      a0, msg_expect_eq
    li      a7, 4
    ecall
    lw      a0, 0(t3)           # expect_eq_data
    li      a7, 34
    ecall
    la      a0, msg_expect_lt
    li      a7, 4
    ecall
    lw      a0, 0(t4)           # expect_lt_data
    li      a7, 34
    ecall
    la      a0, msg_expect_gt
    li      a7, 4
    ecall
    lw      a0, 0(t5)           # expect_gt_data
    li      a7, 34
    ecall
#display message end
#test bf16_eq
    lw      a0, 0(t0)           # load bf16 a test value
    lw      a1, 0(t2)           # load bf16 b test value
    addi    sp, sp, -32         # align 16 bytes
    sw      t5, 20(sp)
    sw      t4, 16(sp)
    sw      t3, 12(sp)
    sw      t2, 8(sp)
    sw      t1, 4(sp)
    sw      t0, 0(sp)
    jal     bf16_eq            # call conversion (a0 is result)
    lw      t0, 0(sp)
    lw      t1, 4(sp)
    lw      t2, 8(sp)
    lw      t3, 12(sp)
    lw      t4, 16(sp)
    lw      t5, 20(sp)
    addi    sp, sp, 32          # align 16 bytes
    mv      s0, a0              # save return value in s0
#display actual start
    la      a0, msg_actual_eq
    li      a7, 4
    ecall
    mv      a0, s0             # display bf16_eq acutal
    li      a7, 34
    ecall
#display actual end
    lw      t6, 0(t3)          # t6 = expect eq data
    bne     t6, s0, test_fail  # check expect eq data != actual eq data
#test bf16_lt
    lw      a0, 0(t0)           # load bf16 a test value
    lw      a1, 0(t2)           # load bf16 b test value
    addi    sp, sp, -32         # align 16 bytes
    sw      t5, 20(sp)
    sw      t4, 16(sp)
    sw      t3, 12(sp)
    sw      t2, 8(sp)
    sw      t1, 4(sp)
    sw      t0, 0(sp)
    jal     bf16_lt            # call conversion (a0 is result)
    lw      t0, 0(sp)
    lw      t1, 4(sp)
    lw      t2, 8(sp)
    lw      t3, 12(sp)
    lw      t4, 16(sp)
    lw      t5, 20(sp)
    addi    sp, sp, 32          # align 16 bytes
    mv      s1, a0              # save return value in s1(lt)
#display actual start
    la      a0, msg_actual_eq
    li      a7, 4
    ecall
    mv      a0, s1             # display bf16_lt acutal
    li      a7, 34
    ecall
#display actual end
    lw      t6, 0(t4)          # t6 = expect lt data
    bne     t6, s1, test_fail  # check expect lt data != actual lt data

#test bf16_lt
    lw      a0, 0(t0)           # load bf16 a test value
    lw      a1, 0(t2)           # load bf16 b test value
    addi    sp, sp, -32         # align 16 bytes
    sw      t5, 20(sp)
    sw      t4, 16(sp)
    sw      t3, 12(sp)
    sw      t2, 8(sp)
    sw      t1, 4(sp)
    sw      t0, 0(sp)
    jal     bf16_gt            # call conversion (a0 is result)
    lw      t0, 0(sp)
    lw      t1, 4(sp)
    lw      t2, 8(sp)
    lw      t3, 12(sp)
    lw      t4, 16(sp)
    lw      t5, 20(sp)
    addi    sp, sp, 32          # align 16 bytes
    mv      s2, a0              # save return value in s2(gt)
#display actual start
    la      a0, msg_actual_eq
    li      a7, 4
    ecall
    mv      a0, s2             # display bf16_gt acutal
    li      a7, 34
    ecall
#display actual end
    lw      t6, 0(t5)          # t6 = expect gt data
    bne     t6, s2, test_fail  # check expect gt data != actual gt data

#display next start
    la      a0, msg_next
    li      a7, 4
    ecall
#display next end
    addi    t0, t0, 4
    addi    t2, t2, 4
    addi    t3, t3, 4
    addi    t4, t4, 4
    addi    t5, t5, 4
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

# bf16_eq/bf16_lt/bf16_gt
# | variable                | Reg   |
# | ----------------------- | ----- |
# | a.bits/result           | a0    |
# | b.bits                  | a1    |
# | a.bits & BF16_EXP_MASK  | s0    |
# | a.bits & BF16_MANT_MASK | s1    |
# | b.bits & BF16_EXP_MAS   | s2    |
# | b.bits & BF16_MANT_MASK | s3    |
# | a.bits & 0x7FFF         | s4    |
# | b.bits & 0x7FFF         | s5    |
# | sign_a(a.bits >> 15) & 1| s6    |
# | sing_b(b.bits >> 15) & 1| s7    |
# | const.imm 0x7FFF        | s8    |
# | const.imm BF16_EXP_MASK | s9    |
# | const.imm BF16_MANT_MASK| s10   |
# |                         | s11   |
# |                         | t0    |
# |                         | t1    |
# |                         | t2    |
# |                         | t3    |
# |                         | t4    |
# |                         | t5    |
# |                         | t6    |
bf16_eq:
    ret

bf16_lt:
    ret

bf16_gt:
    ret