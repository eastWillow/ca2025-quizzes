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

    # --- clz_bitwise function start ---
    # Step 1: propagate leading bits
    slli  t0, a0, 0              # t0 = a0 copy
    srli  t1, a0, 1
    or    t0, t0, t1
    srli  t1, t0, 2
    or    t0, t0, t1
    srli  t1, t0, 4
    or    t0, t0, t1
    srli  t1, t0, 8
    or    t0, t0, t1
    srli  t1, t0, 16
    or    t0, t0, t1
    # Step 2: invert and count bits
    not   t0, t0
    # popcount t0
    li    t1, 0x55555555
    and   t2, t0, t1
    srli  t3, t0, 1
    and   t3, t3, t1
    add   t0, t2, t3          # 2-bit sums
    li    t1, 0x33333333
    and   t2, t0, t1
    srli  t3, t0, 2
    and   t3, t3, t1
    add   t0, t2, t3          # 4-bit sums
    li    t1, 0x0F0F0F0F
    srli  t2, t0, 4
    add   t0, t0, t2
    and   t0, t0, t1          # 8-bit sums
    srli  t2, t0, 8
    add   t0, t0, t2
    srli  t2, t0, 16
    add   t0, t0, t2
    andi  t0, t0, 0x3F        # limit to 32
    mv    a1, t0              # leading zero count
    # --- clz_bitwise function end ---

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