.data
str:  .string "All tests passed.\n"

.text
main:
    la a0, str
    li a7, 4
    ecall
exit:
    li a7, 10
    ecall

# Decode uf8 to uint32_t
uf8_decode:
    # a0 = fl (input)
    # mantissa = fl & 0x0f
    andi  s0, a0, 0x0F       # s0 = mantissa
    # exponent = fl >> 4 (logical)
    srli  s1, a0, 4          # s1 = exponent
    # offset = (0x7FFF >> (15 - exponent)) << 4
    li    s2, 15
    sub   s3, s2, s1         # s3 = 15 - exponent
    li    s4, 0x7FFF
    srl   s4, s4, s3         # s4 = 0x7FFF >> (15 - exponent)
    slli  s4, s4, 4          # offset = s4 << 4
    # result = (mantissa << exponent) + offset
    sll   s0, s0, s1         # mantissa << exponent
    add   a0, s0, s4         # result
    ret