ARCH = -march=rv32i_zicsr -mabi=ilp32
LINKER_SCRIPT = linker.ld
CROSS_COMPILE = riscv-none-elf-

AFLAGS = -g $(ARCH)
CFLAGS = -g -Ofast $(ARCH)
LDFLAGS = -T $(LINKER_SCRIPT)
EXEC = test.elf

CC = $(CROSS_COMPILE)gcc
AS = $(CROSS_COMPILE)as
LD = $(CROSS_COMPILE)ld
OBJDUMP = $(CROSS_COMPILE)objdump

OBJS = start.o uf8_encode.o perfcounter.o print.o

.PHONY: all run dump clean

all: $(EXEC)

$(EXEC): $(OBJS) $(LINKER_SCRIPT)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

%.o: %.S
	$(AS) $(AFLAGS) $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) $< -o $@ -c

dump: $(EXEC)
	$(OBJDUMP) -Ds $< | less

clean:
	rm -f $(EXEC) $(OBJS)