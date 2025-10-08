.data
test_data:
    .word 0x00000000    # +0.0
    .word 0x80000000    # -0.0
    .word 0x7F800000    # +inf
    .word 0xFF800000    # -inf
    .word 0x7FC00000    # NaN (quiet)
    .word 0x3F800000    # 1.0
    .word 0x3F000000    # 0.5
    .word 0x40000000    # 2.0
    .word 0x3F818000    # 1.0117188f  (round up)
    .word 0x3F808000    # 1.0039063f  (round down)
    .word 0x3F817000    # 1.0112305f  (round donw)
    .word 0xBF818000    # -1.0117188f (round up)
    .word 0xBF817000    # -1.0112305f (round down)
test_data_end:
    .word 0xFFFFFFFF
expect_data:
    .word 0x0000
    .word 0x8000
    .word 0x7F80
    .word 0xFF80
    .word 0x7FC0
    .word 0x3F80
    .word 0x3F00
    .word 0x4000
    .word 0x3F82
    .word 0x3F80
    .word 0x3F81
    .word 0xBF82
    .word 0xBF81
expect_data_end:
    .word 0xFFFFFFFF

msg_float: .string "Float:"
msg_bf16:  .string "BF16:"
msg_pass:  .string "OK\n"
msg_fail:  .string "FAIL\n"

.text

main:
    la      t2, test_data       # t2 -> test_data
    la      t3, test_data_end   # t3 -> test_data_end
    la      t4, expect_data     # t4 -> expect data
loop:
    beq     t2, t3, test_pass   # done if no more test cases
    lw      a0, 0(t2)           # load test value
    jal     f32_to_bf16         # call conversion (a0 is result)
    lw      t5, 0(t4)           # t5 = expect_data
    bne     t5, a0, test_fail
    addi    t2, t2, 4           # next test case
    addi    t4, t4, 4           # next expect
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

# a0 = float bits (uint32_t)
# return a0 = bf16.bits (uint16_t)
f32_to_bf16:
    # --- Step 1: exponent & sign
    srli    t0, a0, 23          # t0 = f32bits >> 23
    andi    t0, t0, 0xFF        # t0 = t0 & 0xFF
    li      t1, 0xFF
    beq     t0, t1, nan_inf     # if exp == 0xFF → NaN/Inf path
    # --- Step 2: rounding: ((f32bits >> 16) & 1) + 0x7FFF
    srli    t0, a0, 16          # t0 = f32bits >> 16
    andi    t0, t0, 1           # t0 = (f32bits >> 16) & 1
    li      t1, 0x7FFF
    add     t0, t0, t1          # t0 = ((f32bits>>16)&1) + 0x7FFF
    add     a0, a0, t0          # f32bits += t0
nan_inf:
    srli    a0, a0, 16          # a0 = f32bits >> 16
    ret