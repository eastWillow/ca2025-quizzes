.data
test_pass_str:  .string "All tests passed.\n"
test_fail_str:  .string "Test Fail.\n"
not_equ_str:    .string " not equ.\n"
encdoe_str:     .string " encode :"
decode_str:     .string " decode :"
input_str:      .string "input :"
change_line_str:.string "\n"

.text
main:
    li      t0, -1                          # int32_t previous_value = -1;
    li      t1, 1                           # bool passed = true;
    li      t2, 0                           # int i = 0;
    li      t3, 256                         # 256
    # for (int i = 0; i < 256; i++)
main_loop:
    bge     t2, t3, main_loop_done
    mv      a0, t2                          # a0 = t2 (i)
    addi    sp, sp, -20
    sw      t3, 16(sp)
    sw      t2, 12(sp)
    sw      t1, 8(sp)
    sw      t0, 4(sp)
    jal     ra, uf8_decode                  # a0 = uf8_decode(a0)
    mv      t4, a0                          # t4 = uf8_decode result
    lw      t0, 4(sp)
    lw      t1, 8(sp)
    lw      t2, 12(sp)
    lw      t3, 16(sp)
    addi    sp, sp, 20

    mv      a0, t4
    addi    sp, sp, -24
    sw      t4, 20(sp)
    sw      t3, 16(sp)
    sw      t2, 12(sp)
    sw      t1, 8(sp)
    sw      t0, 4(sp)
    jal     ra, uf8_encode                  # a0 = uf8_encode(a0)
    mv      t5, a0                          # t5 = uf8_encode result
    lw      t0, 4(sp)
    lw      t1, 8(sp)
    lw      t2, 12(sp)
    lw      t3, 16(sp)
    lw      t4, 20(sp)
    addi    sp, sp, 24

    # la      a0, input_str
    # li      a7, 4
    # ecall
    # mv      a0, t2
    # li      a7, 34
    # ecall
    # la      a0, decode_str
    # li      a7, 4
    # ecall
    # mv      a0, t4
    # li      a7, 34
    # ecall
    # la      a0, encdoe_str
    # li      a7, 4
    # ecall
    # mv      a0, t5
    # li      a7, 34
    # ecall

    beq     t2, t5, decode_value_equ_encode_value
decode_value_noe_equ_encode_value:
    # la      a0, not_equ_str
    # li      a7, 4
    # ecall

    mv      t1, x0
decode_value_equ_encode_value:
    # la      a0, change_line_str
    # li      a7, 4
    # ecall

    addi    t2, t2, 1   # i = i + 1
    j       main_loop

main_loop_done:
    bne     t1, x0, test_pass
    la      a0, test_fail_str
    li      a7, 4
    ecall
    j       exit
test_pass:
    la      a0, test_pass_str
    li      a7, 4
    ecall
exit:
    li      a7, 10
    ecall

# Decode uf8 to uint32_t
uf8_decode:
    # a0 = fl (input)
    # mantissa = fl & 0x0f
    andi    s0, a0, 0x0F       # s0 = mantissa
    # exponent = fl >> 4 (logical)
    srli    s1, a0, 4          # s1 = exponent
    # offset = (0x7FFF >> (15 - exponent)) << 4
    li      s2, 15
    sub     s3, s2, s1         # s3 = 15 - exponent
    li      s4, 0x7FFF
    srl     s4, s4, s3         # s4 = 0x7FFF >> (15 - exponent)
    slli    s4, s4, 4          # offset = s4 << 4
    # result = (mantissa << exponent) + offset
    sll     s0, s0, s1         # mantissa << exponent
    add     a0, s0, s4         # result
    ret

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