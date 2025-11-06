# Startup code for bare metal RISC-V
    .section .rodata
    .align 2
str:
    .ascii "Hello World\n"
     .set str_size, .-str
endl:
    .ascii "\n"
     .set endl_size, .-endl

    .section .text._start
    .globl _start
    .extern printstr

_start:
    # Set up stack pointer
    la sp, __stack_top

    # Clear BSS
    la t0, __bss_start
    la t1, __bss_end
1:
    bge t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b

2:
    # Call main
    la a0, str   # address of string
    li a1, str_size  # length of string
    call printstr

    li a0, 55
    call print_dec
    la a0, endl   # address of string
    li a1, endl_size  # length of string
    call printstr

    li a0, 0xAA
    call print_hex
    la a0, endl   # address of string
    li a1, endl_size  # length of string
    call printstr

    # Exit syscall (if main returns)
    li a7, 93    # exit syscall number
    li a0, 0     # exit code
    ecall

    # Infinite loop (should never reach here)
3:
    j 3b

.size _start, .-_start

# Provide BSS markers if linker script doesn't define them
.weak __bss_start
.weak __bss_end
.weak __stack_top
