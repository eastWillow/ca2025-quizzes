    .text
    .globl  main
main:
    addi    x2, x2, -32
    sw      x8, 0(x2)
    sw      s1, 4(x2)
    sw      x18, 8(x2)
    sw      x19, 12(x2)
    sw      x20, 16(x2)

    li      t0, 0x15
    sw      t0, 20(x2)
    sw      t0, 24(x2)
    sw      t0, 28(x2)

    # Fix disk positions (BLANK 1-3: neutralize t0 effect)
    # BLANK 1: Fix position at x2+20
    sw      x0, 20(x2)

    # BLANK 2: Fix position at x2+24
    sw      x0, 24(x2)

    # BLANK 3: Fix position at x2+28
    sw      x0, 28(x2)

    addi    x8, x0, 1
game_loop:
    # BLANK 4: Check loop termination (2^3 moves)
    addi    t0, x0, 8
    beq     x8, t0, finish_game

    # Gray code formula: gray(n) = n XOR (n >> k)
    # BLANK 5: What is k for Gray code?
    srli    t0, x8, 1

    # BLANK 6: Complete Gray(n) calculation
    xor     x6, x8, t0

    # BLANK 7-8: Calculate previous value and its shift
    addi    t2, x8, -1
    srli    x28, t2, 1

    # BLANK 9: Generate Gray(n-1)
    xor     t2, t2, x28

    # BLANK 10: Which bits changed?
    xor     t0, x6, t2

    # Initialize disk number
    addi    s1, x0, 0

    # BLANK 11: Mask for testing LSB
    andi    x6, t0, 1

    # BLANK 12: Branch if disk 0 moves
    bne     x6, x0, disk_found

    # BLANK 13: Set disk 1
    addi    s1, x0, 1

    # BLANK 14: Test second bit with proper mask
    andi    x6, t0, 2
    bne     x6, x0, disk_found

    # BLANK 15: Last disk number
    addi    s1, x0, 2

disk_found:
    # BLANK 16: Check impossible pattern (multiple bits)
    andi    x30, t0, 5
    addi    x31, x0, 5
    beq     x30, x31, pattern_match
    jal     x0, continue_move
pattern_match:
continue_move:

    # BLANK 17: Word-align disk index (multiply by what?)
    slli    t0, s1, 2

    # BLANK 18: Base offset for disk array
    addi    t0, t0, 20
    add     t0, x2, t0
    lw      x18, 0(t0)

    bne     s1, x0, handle_large

    # BLANK 19: Small disk moves by how many positions?
    addi    x19, x18, 2

    # BLANK 20: Number of pegs
    addi    x6, x0, 3
    blt     x19, x6, display_move
    sub     x19, x19, x6
    jal     x0, display_move

handle_large:
    # BLANK 21: Load reference disk position
    lw      x6, 20(x2)

    # BLANK 22: Sum of all peg indices (0+1+2)
    addi    x19, x0, 3
    sub     x19, x19, x18
    sub     x19, x19, x6

display_move:
    la      x20, obdata
    add     t0, x20, x18

    # BLANK 23: Load byte from obfuscated data
    lbu     a1, 0(t0)

    # BLANK 24: Decode constant (0x6F)
    li      x6, 0x6F
    xor     a1, a1, x6

    # BLANK 25: Final offset adjustment
    addi    a1, a1, -0x12

    add     t2, x20, x19
    lbu     a2, 0(t2)
    xor     a2, a2, x6
    addi    a2, a2, -0x12

    la      a0, str1
    addi    a7, x0, 4
    ecall
    addi    a0, s1, 1
    addi    a7, x0, 1
    ecall
    la      a0, str2
    addi    a7, x0, 4
    ecall
    addi    a0, a1, 0
    addi    a7, x0, 11
    ecall
    la      a0, str3
    addi    a7, x0, 4
    ecall
    addi    a0, a2, 0
    addi    a7, x0, 11
    ecall
    addi    a0, x0, 10
    addi    a7, x0, 11
    ecall

    # BLANK 26: Calculate storage offset
    slli    t0, s1, 2
    addi    t0, t0, 20
    add     t0, x2, t0

    # BLANK 27: Update disk position
    sw      x19, 0(t0)

    # BLANK 28-29: Increment counter and loop
    addi    x8, x8, 1
    jal     x0, game_loop

finish_game:
    lw      x8, 0(x2)
    lw      s1, 4(x2)
    lw      x18, 8(x2)
    lw      x19, 12(x2)
    lw      x20, 16(x2)
    addi    x2, x2, 32
    addi    a7, x0, 10
    ecall

    .data
obdata:     .byte   0x3c, 0x3b, 0x3a
str1:       .asciz  "Move Disk "
str2:       .asciz  " from "
str3:       .asciz  " to "
