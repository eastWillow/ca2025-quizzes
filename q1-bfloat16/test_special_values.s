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
test_pos_inf_is_inf_str:    .string "pos inf is inf: "
test_pos_inf_not_nan_str:   .string "pos inf not nan: "
test_neg_inf_is_inf_str:    .string "neg inf is inf: "
test_pass_str:              .string "pass\n"
test_fail_str:              .string "fail\n"


.text
main:
test_pos_inf_is_inf_start:
    la      a0, test_pos_inf_is_inf_str
    li      a7, 4
    ecall
    li      a0, BF16_POS_INF
    jal     bf16_isinf
    bnez    a0, test_pos_inf_is_inf_pass
test_pos_inf_is_inf_fail:
    la      a0, test_fail_str
    li      a7, 4
    ecall
    j       test_pos_inf_is_inf_done  # jump to test_inf_done
test_pos_inf_is_inf_pass:
    la      a0, test_pass_str
    li      a7, 4
    ecall
test_pos_inf_is_inf_done:

test_pos_inf_not_nan_start:
    la      a0, test_pos_inf_not_nan_str
    li      a7, 4
    ecall
    li      a0, BF16_POS_INF
    jal     bf16_isnan
    beqz    a0, test_pos_inf_not_nan_pass
test_pos_inf_not_nan_fail:
    la      a0, test_fail_str
    li      a7, 4
    ecall
    j       test_pos_inf_not_nan_done  # jump to test_inf_done
test_pos_inf_not_nan_pass:
    la      a0, test_pass_str
    li      a7, 4
    ecall
test_pos_inf_not_nan_done:

test_neg_inf_is_inf_start:
    la      a0, test_neg_inf_is_inf_str
    li      a7, 4
    ecall
    li      a0, BF16_NEG_INF
    jal     bf16_isinf
    bnez    a0, test_neg_inf_is_inf_pass
test_neg_inf_is_inf_fail:
    la      a0, test_fail_str
    li      a7, 4
    ecall
    j       test_neg_inf_is_inf_done  # jump to test_inf_done
test_neg_inf_is_inf_pass:
    la      a0, test_pass_str
    li      a7, 4
    ecall
test_neg_inf_is_inf_done:

main_done:
    li      a7, 10
    ecall

bf16_isnan:
    li      t0, BF16_EXP_MASK       # t0 = exponent mask
    and     t1, a0, t0              # t1 = a.bits & BF16_EXP_MASK
    bne     t1, t0, not_nan         # if (t1 != BF16_EXP_MASK) return 0
    andi    t1, a0, BF16_MANT_MASK  # t1 = a.bits & 0x007F
    beqz    t1, not_nan             # if (mantissa == 0) return 0
    li      a0, 1                   # both true -> return 1
    ret
not_nan:
    li      a0, 0
    ret

bf16_isinf:
    li      t0, BF16_EXP_MASK   # t0 = exponent mask
    and     t1, a0, t0          # t1 = a.bits & BF16_EXP_MASK
    bne     t1, t0, not_inf     # if (t1 != BF16_EXP_MASK) return 0
    andi    t1, a0, BF16_MANT_MASK  # t1 = a.bits & 0x007F
    bnez    t1, not_inf         # if (mantissa != 0) return 0
    li      a0, 1               # both true -> return 1
    ret
not_inf:
    li      a0, 0
    ret

bf16_iszero:
    li      t0, BF16_BITS       # t0 = BF16 all bits
    and     t1, a0, t0          # t1 = a.bits & BF16_BITS
    bnez    t1, not_zero
    li      a0, 1
    ret
not_zero:
    li      a0, 0
    ret