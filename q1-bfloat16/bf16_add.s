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

bf16_add:
