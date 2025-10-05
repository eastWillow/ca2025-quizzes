.data
test_values:
    .word 0x00000000, 0x00000001, 0x0000000F, 0x00000010,
    .word 0x00000100, 0x00001000, 0x00010000, 0x00020000,
    .word 0x00040000, 0x00080000, 0x000F7FF0, 0x000FFFFF

expect_values:
    .byte 0x00, 0x01, 0x0F, 0x10, 0x41, 0x80,
    .byte 0xC0, 0xD0, 0xE0, 0xF0, 0xFF, 0xFF

correct_str:    .string "correct\n"
wrong_str:      .string "wrong\n"

.text
main:
    la      t0, test_values       # t0 = &test_values
    la      t1, expect_values     # t1 = &expect_values
    li      t2, 12                # t2 = n = 12

loop:
    beqz    t2, end
    lw      a0, 0(t0)             # load value
    jal     ra, uf8_encode        # encode
    mv      t3, a0                # t3 = result
    lbu     t4, 0(t1)             # load expect
    beq     t3, t4, correct
    # mismatch, set t3 = 0 (wrong)
    la      a0, wrong_str
    li      a7, 4
    ecall
    j       next
correct:
    la      a0, correct_str
    li      a7, 4
    ecall
next:
    addi    t0, t0, 4
    addi    t1, t1, 1
    addi    t2, t2, -1
    j       loop

end:
    li a7, 10                    # exit
    ecall

uf8_encode:
    # a0 = uf8_encode (a0)
    # --- if (value < 16) return value; ---
    li      t0, 16
    bgeu    a0, t0, call_bitwise
    ret

clz_bitwise:
    # --- clz_bitwise function start ---
    # a0 is input & output
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
    mv    a0, t0              # leading zero count
    ret
    # --- clz_bitwise function end ---
