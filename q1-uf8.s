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