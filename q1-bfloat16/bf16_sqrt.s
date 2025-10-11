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
    .word 0x00007FC1 # NaN
    .word 0x00007F80 # +Inf
    .word 0x0000FF80 # -Inf
    .word 0x00000000 # +0
    .word 0x00008000 # -0
    .word 0x0000B400 # -0.00000011920929
    .word 0x00000040 # 5.877472e-39
    .word 0x00004000 # 2.0
    .word 0x00003F80 # 1.0
    .word 0x00003E80 # 0.25
    .word 0x00007E80 # 8.507059e37
    .word 0x00000080 # 1.1754944e-38
    .word 0x0000407F # 3.984375 result is 255
test_a_data_end:
    .word 0xFFFFFFFF

expect_sqrt_data:
    .word 0x00007FC1  # sqrt(NaN) = NaN
    .word 0x00007F80  # sqrt(+Inf) = + Inf
    .word 0x00007FC0  # sqrt(-Inf) = NaN
    .word 0x00000000  # sqrt(+0)   = +0
    .word 0x00000000  # sqrt(-0)   = +0
    .word 0x00007FC0  # sqrt(-0.75) = NaN
    .word 0x00000000  # sqrt(5.877472e-39) = 0
    .word 0x00003FB5  # sqrt(2.0) = 1.4140625
    .word 0x00003F80  # sqrt(1.0) = 1.0
    .word 0x00003F00  # sqrt(0.25) = 0.5
    .word 0x00005F00  # 9.223372e18
    .word 0x00002000  # 1.0842022e-19
    .word 0x00003FFF  # sqrt(3.984375) = 1.9921875

msg_a:  .string "a: "
msg_expect_sqrt:  .string " expect sqrt: "
msg_actual_sqrt:  .string " actual sqrt: "
msg_next:  .string " \n"
msg_all_pass:  .string "ALL PASS\n"
msg_fail:  .string "FAIL\n"

.text
main:
    la      t0, test_a_data      # t0 -> test_a_data
    la      t1, test_a_data_end  # t1 -> test_a_data_end
    la      t2, expect_sqrt_data # t3 -> expect_sqrt_data
loop:
    beq     t0, t1, test_pass    # done if no more test cases
#display message start
    la      a0, msg_a
    li      a7, 4
    ecall
    lw      a0, 0(t0)           #
    li      a7, 34
    ecall
    la      a0, msg_expect_sqrt
    li      a7, 4
    ecall
    lw      a0, 0(t2)           #
    li      a7, 34
    ecall
#display message end
    lw      a0, 0(t0)           # load bf16 a test value
    addi    sp, sp, -16         # align 16 bytes
    sw      t2, 8(sp)
    sw      t1, 4(sp)
    sw      t0, 0(sp)
    jal     bf16_sqrt           # call conversion (a0 is result)
    lw      t0, 0(sp)
    lw      t1, 4(sp)
    lw      t2, 8(sp)
    addi    sp, sp, 16          # align 16 bytes
    mv      a2, a0              # save return value in a2

#display actual start
    la      a0, msg_actual_sqrt
    li      a7, 4
    ecall
    mv      a0, a2             # display bf16_sqrt acutal
    li      a7, 34
    ecall
    la      a0, msg_next
    li      a7, 4
    ecall
#display actual end
    lw      t5, 0(t2)          # t5 = expect sub data
    bne     t5, a2, test_fail  # check expect add data != actual add data
    addi    t0, t0, 4
    addi    t2, t2, 4
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

# bf16_sqrt
# | variable                | Reg   |
# | ----------------------- | ----- |
# | a.bits/result           | a0    |
# | b.bits                  | a1    |
# | sign                    | s0    |
# | exp                     | s1    |
# | mant                    | s2    |
# | const. imm 0xFF         | s3    |
# | const. imm BF16_NAN     | s4    |
# | const. imm 1            | s5    |
# | const. imm BF16_POS_INF | s6    |
# | e/(mid << i)            | s7    |
# | new_exp                 | s8    |
# | low                     | s9    |
# | high                    | s10   |
# | i                       | s11   |
# | result                  | t0    |
# | mid                     | t1    |
# | sq                      | t2    |
# | new_mant                | t3    |
# | const. imm BF16_EXP_BIAS| t4    |
# | mask                    | t5    |
# | const. imm 32           | t6    |

bf16_sqrt:
    # load the const imm to register
    # sign = (a.bits >> 15) & 1
    srli    s0, a0, 15
    andi    s0, s0, 1
    # exp = ((a.bits >> 7) & 0xFF);
    srli    s1, a0, 7
    andi    s1, s1, 0xFF
    # mant = a.bits & 0x7F;
    andi    s2, a0, 0x7F
    # load const imm
    addi    s3, x0, 0xFF
    li      s4, BF16_NAN
    addi    s5, x0, 1
    li      s6, BF16_POS_INF
    addi    t4, x0, BF16_EXP_BIAS
    addi    t6, x0, 32
check_exp_nan:
    bne     s1, s3, check_sqrt_zero
    beqz    s2, check_inf_sign
    ret     # return a0
check_inf_sign:
    beqz    s0, return_a
    mv      a0, s4 # a0 = BF16_NAN
return_a:
    ret     # return

check_sqrt_zero:
    bnez    s1, check_neg_sign
    bnez    s2, check_neg_sign
    mv      a0, x0 # a0 = 0
    ret     # return

check_neg_sign:
    beqz    s0, check_exp_denormal
    mv      a0, s4 # a0 = BF16_NAN
    ret

check_exp_denormal:
    bnez    s1, bit_square_roo_algotithm
    mv      a0, x0 # a0 = 0
    ret

bit_square_roo_algotithm:
    sub     s7, s1, t4 # e = exp - BF16_EXP_BIAS;
    ori     s2, s2, 0x80 # mant = 0x80 | mant
    andi    t5, s7, 1  # mask = (e & 1)
    sll     s2, s2, t5 # mant <<= mask
    sub     s8, s7, t5 # new_exp = e - mask
    srai    s8, s8, 1  # new_exp >>= 1 new_exp is int32_t so need use arithmetic shift
    add     s8, s8, t4 # new_exp += BF16_EXP_BIAS
binary_search_for_square_root_of_m_init:
    addi    s9, x0, 90  # low = 90
    addi    s10,x0, 256 # high = 256
    addi    t0, x0, 128 # result = 128
binary_search_loop:
    bgt     s9, s10, binary_search_loop_done
    add     t1, s9, s10 # mid = mid = (low + high)
    srli    t1, t1, 1   # mid >>= 1

    j       binary_search_loop
binary_search_loop_done:
    ret