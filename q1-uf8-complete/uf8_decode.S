.data
test_values:
    .byte 0x00, 0x01, 0x0F, 0x10, 0x1F, 0x20, 0x2F, 0x30, 0x3F, 0xF0, 0xFF
    .align 2
expect_values:
    .word 0, 1, 15, 16, 46, 48, 108, 112, 232, 524272, 1015792
correct_str:
    .string "correct\n"
    .set correct_str_size, .-correct_str
wrong_str:
    .string "wrong\n"
    .set wrong_str_size, .-wrong_str

.equ n_tests, 11

.text
.globl main
.align 2

main:
    la   t0, test_values       # t0 = &test_values
    la   t1, expect_values     # t1 = &expect_values
    li   t2, n_tests
    li   t3, 0                 # t3 = loop counter i

loop_start:
    beq  t3, t2, exit          # if i == n_tests, exit loop

    lbu   a0, 0(t0)            # load test_values[i] → a0 # Care ful the sign extend
    jal  ra, uf8_decode        # call uf8_decode, result in a0
    lw   t4, 0(t1)             # load expected value
    bne  a0, t4, test_fail     # if decoded != expected, jump to fail

    add a7, x0, 0x40           #
    add a0, x0, 0x1            # stdout
    la  a1, correct_str        #
    li  a2, correct_str_size
    ecall

    addi t0, t0, 1             # advance test_values pointer
    addi t1, t1, 4             # advance expect_values pointer
    addi t3, t3, 1             # loop counter = loop counter + 1
    jal  x0, loop_start

exit:
    li a7, 93           # exit syscall number
    li a0, 0            # exit code 0
    ecall

test_fail:
    # optional: indicate failure
    add a7, x0, 0x40           #
    add a0, x0, 0x1            # stdout
    la  a1, wrong_str        #
    li  a2, wrong_str_size
    ecall
    li   a7, 93         # exit syscall
    li   a0, 1          # return code 1
    ecall

uf8_decode:
    # a0 = fl (input)
    # mantissa = fl & 0x0f
    andi  s0, a0, 0x0F       # s0 = mantissa
    # exponent = fl >> 4 (logical)
    srli  s1, a0, 4          # s1 = exponent
    # offset = ((1U << exponent) - 1) << 4;
    li    s2, 1              #
    sll   s2, s2, s1         # s2 = 1 << exponent
    slli  s2, s2, 4          # s2 = (1 << e) << 4 = (1 << e) * 16
    addi  s2, s2, -16        # s2 -= 16
    # result = (mantissa << exponent) + offset
    sll   s0, s0, s1         # mantissa << exponent
    add   a0, s0, s2         # result
    ret
