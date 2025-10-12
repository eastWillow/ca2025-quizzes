.data
correct_str:    .string "correct\n"
wrong_str:      .string "wrong\n"
input_array:
    .word 0x00000000, 0x00000001, 0x00000002, 0x0000000F
    .word 0x00000010, 0x00000080, 0x0000FFFF, 0x00FF0000
    .word 0x08000000, 0x10000000, 0x80000000, 0xFFFFFFFF

expect_array:
    .word 32, 31, 30, 28
    .word 27, 24, 16,  8
    .word 4 ,  3,  0,  0

output_array:
    .word 0,0,0,0,0,0,0,0,0,0,0,0 # 12 * 4 bytes

.equ test_array_len, 12

.text
.globl _start
_start:
    la    s0, input_array       # input pointer
    la    s1, expect_array      # expect pointer
    la    s2, output_array      # output pointer
    li    s3, test_array_len    # counter

loop_array:
    beqz  s3, end

    lw    a0, 0(s0)             # load input element

    # --- clz_loop function start ---
    li    a1, 32                # n = 32
    li    a2, 16                # c = 16
clz_bs_loop:
    beqz  a2, clz_bs_done   # if c == 0, exit loop
    srl   t0, a0, a2        # y = x >> c
    beqz  t0, clz_bs_skip   # if y == 0, skip
    sub   a1, a1, a2        # n -= c
    mv    a0, t0            # x = y
clz_bs_skip:
    srai  a2, a2, 1         # c >>= 1 (arithmetic or logical shift both work)
    j     clz_bs_loop
clz_bs_done:
    sub   a1, a1, a0        # return n - x in a1
    # --- clz_loop function end ---

    # store result to output_array
    sw    a1, 0(s2)

    # compare with expect_array
    lw    t2, 0(s1)             # expected
    beq   a1, t2, correct
    # if mismatch, set t3 = 0 (wrong)
    li    t3, 0
    # print wrong string
    la a0, wrong_str
    li a7, 4
    ecall
    j     next
correct:
    li    t3, 1                  # correct
    # print correct string
    la a0, correct_str
    li a7, 4
    ecall
next:

    addi  s0, s0, 4             # next input
    addi  s1, s1, 4             # next expect
    addi  s2, s2, 4             # next output
    addi  s3, s3, -1
    j     loop_array

end:
    li a7, 10                    # exit
    ecall