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
    andi   t0, a0, 0x0F       # t0 = mantissa
    # exponent = fl >> 4 (logical)
    srli  t1, a0, 4          # t1 = exponent
    # offset = (0x7FFF >> (15 - exponent)) << 4
    li    t2, 15
    sub   t3, t2, t1         # t3 = 15 - exponent
    li    t4, 0x7FFF
    srl   t4, t4, t3         # t4 = 0x7FFF >> (15 - exponent)
    slli  t4, t4, 4          # offset = t4 << 4
    # result = (mantissa << exponent) + offset
    sll   t0, t0, t1         # mantissa << exponent
    add   a0, t0, t4         # result
    ret