.data
test_data:
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
test_data_end:
    .word 0xFFFFFFFF
expect_data:
    .word 0x00000000    # +0.0
    .word 0x80000000    # -0.0
    .word 0x7F800000    # +inf
    .word 0xFF800000    # -inf
    .word 0x7FC00000    # NaN (quiet)
    .word 0x3F800000    # 1.0
    .word 0x3F000000    # 0.5
    .word 0x40000000    # 2.0
    .word 0x3F820000    #
    .word 0x3F800000    #
    .word 0x3F810000    #
    .word 0xBF820000    #
    .word 0xBF810000    #
expect_data_end:
    .word 0xFFFFFFFF
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
    jal     bf16_to_f32         # call conversion (a0 is result)
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

bf16_to_f32:
    slli    a0, a0, 16
    ret