.data
test_values:
    .word 0x00000000, 0x00000001, 0x0000000F, 0x00000010
    .word 0x00000100, 0x00001000, 0x00010000, 0x00020000
    .word 0x00040000, 0x00080000, 0x000F7FF0, 0x000FFFFF

expect_values:
    .byte 0x00, 0x01, 0x0F, 0x10, 0x41, 0x80
    .byte 0xC0, 0xD0, 0xE0, 0xF0, 0xFF, 0xFF

correct_str:
    .string "correct\n"
    .set correct_str_size, .-correct_str

wrong_str:
    .string "wrong\n"
    .set wrong_str_size, .-wrong_str
cycles_str:
    .string "Cycles:"
    .set cycles_str_size, .-cycles_str
endl:
    .ascii "\n"
    .set endl_size, .-endl

.text
.globl main
.align 1
.type main, @function

main:
    la      t0, test_values       # t0 = &test_values
    la      t1, expect_values     # t1 = &expect_values
    li      t2, 12                # t2 = n = 12

loop:
    beqz    t2, end
    lw      a0, 0(t0)             # load value

    # call uf8_encode
    addi    sp, sp, -28
    sw      t2, 24(sp)
    sw      t1, 20(sp)
    sw      t0, 16(sp)
    sw      ra, 12(sp)
    sw      a0, 8(sp)
    jal     ra, uf8_encode        # encode
    mv      t3, a0                # t3 = result
    lw      a0, 8(sp)
    lw      ra, 12(sp)
    lw      t0, 16(sp)
    lw      t1, 20(sp)
    lw      t2, 24(sp)
    addi    sp, sp, 28

    lbu     t4, 0(t1)             # load expect
    beq     t3, t4, correct
    # mismatch, set t3 = 0 (wrong)
    add a7, x0, 0x40           #
    add a0, x0, 0x1            # stdout
    la  a1, wrong_str          #
    li  a2, wrong_str_size
    ecall
    j       next
correct:
    add a7, x0, 0x40           #
    add a0, x0, 0x1            # stdout
    la  a1, correct_str        #
    li  a2, correct_str_size
    ecall
next:
    addi    t0, t0, 4
    addi    t1, t1, 1
    addi    t2, t2, -1
    j       loop

end:
    li   a7, 93         # exit syscall
    li   a0, 0          # return code 0
    ecall

uf8_encode:
    # a0 = uf8_encode (a0)
    # --- if (value < 16) return value; ---
    li      t0, 16
    bgeu    a0, t0, call_bitwise
    ret
call_bitwise:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      a0, 8(sp)
    jal     ra, clz_bitwise                 # a0 = clz_bitwise(a0)
    mv      t1, a0                          # t1 = lz (leading zeros)
    lw      a0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    # msb = 31 - lz ---
    li      t2, 31
    sub     t2, t2, t1                      # t2 = msb(t2) - lz(t1)
    # exponent=0, overflow=0
    li      t3, 0                           # t3 = exponent
    li      t4, 0                           # t4 = overflow

    li      t5, 5
    blt     t2, t5, find_exact_exponent     # if(msb < 5) goto find_exact_exponent
    addi    t3, t2, -4                      # exponent = msb - 4
    li      t5, 15
    bleu    t3, t5, exponent_ok             # if(t3 <= 15) goto exponent_ok
exponent_cap:
    li      t3, 15                          # if(t3 > 15) t3 = 15
exponent_ok:

    li      t6, 0                           # uint8_t e = 0;
overflow_loop:
    bge     t6, t3, overflow_loop_done      # if(e >= exponent) goto overflow_loop_done
    slli    t4, t4, 1                       # overflow <<= 1
    addi    t4, t4, 16                      # overflow += 16
    addi    t6, t6, 1                       # t6 = t6 + 1
    j       overflow_loop
overflow_loop_done:
    li      t5, 15
find_exact_exponent:
    bge     t3, t5, calculate_mantissa      # if(exponent > 15) goto calculate_mantissa
    # next_overflow = (overflow << 1) + 16;
    slli    t6, t4, 1
    addi    t6, t6, 16
    bltu    a0, t6, calculate_mantissa      # if (input < next_overflow) goto calculate_mantissa
    mv      t4, t6                          # overflow = next_overflow;
    addi    t3, t3, 1                       # exponent = exponent + 1;
    j       find_exact_exponent
calculate_mantissa:
    # mantissa = (value - overflow) >> exponent
    sub     t6, a0, t4                      # mantissa = (value - overflow)
    srl     t6, t6, t3                      # mantissa = mantissa >> exponent
    li      t5, 15
    bleu    t6, t5, mantissa_ok             # if(mantissa <= 15) goto mantissa_ok
mantissa_cap:
    li      t6, 15                          # if(mantissa >  15) mantissa = 15
mantissa_ok:
    # return (exponent << 4) + mantissa
    slli    t3, t3, 4                       # exponent = exponent << 4
    add     a0, t3, t6                      # a0 = exponent + mantissa
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
