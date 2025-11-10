#include <stdbool.h>
#include <stdint.h>

#define printstr(ptr, length)                    \
    do {                                         \
        asm volatile(                            \
            "add a7, x0, 0x40;"                  \
            "add a0, x0, 0x1;" /* stdout */      \
            "add a1, x0, %0;"                    \
            "mv a2, %1;" /* length character */  \
            "ecall;"                             \
            :                                    \
            : "r"(ptr), "r"(length)              \
            : "a0", "a1", "a2", "a7", "memory"); \
    } while (0)

#define TEST_OUTPUT(msg, length) printstr(msg, length)

#define TEST_LOGGER(msg)                     \
    {                                        \
        char _msg[] = msg;                   \
        TEST_OUTPUT(_msg, sizeof(_msg) - 1); \
    }

/* Software division for RV32I (no M extension) */
static unsigned long udiv(unsigned long dividend, unsigned long divisor)
{
    if (divisor == 0)
        return 0;

    unsigned long quotient = 0;
    unsigned long remainder = 0;

    for (int i = 31; i >= 0; i--) {
        remainder <<= 1;
        remainder |= (dividend >> i) & 1;

        if (remainder >= divisor) {
            remainder -= divisor;
            quotient |= (1UL << i);
        }
    }

    return quotient;
}

static unsigned long umod(unsigned long dividend, unsigned long divisor)
{
    if (divisor == 0)
        return 0;

    unsigned long remainder = 0;

    for (int i = 31; i >= 0; i--) {
        remainder <<= 1;
        remainder |= (dividend >> i) & 1;

        if (remainder >= divisor) {
            remainder -= divisor;
        }
    }

    return remainder;
}

/* Simple integer to decimal string conversion */
static void print_dec(unsigned long val)
{
    char buf[20];
    char *p = buf + sizeof(buf) - 1;
    *p = '\0';
    p--;

    if (val == 0) {
        *p = '0';
        p--;
    } else {
        while (val > 0) {
            *p = '0' + umod(val, 10);
            p--;
            val = udiv(val, 10);
        }
    }

    p++;
    printstr(p, (buf + sizeof(buf) - p));
}

/* Simple integer to hex string conversion */
static void print_hex(unsigned long val)
{
    char buf[20];
    char *p = buf + sizeof(buf) - 1;
    *p = '\0';
    p--;

    if (val == 0) {
        *p = '0';
        p--;
    } else {
        while (val > 0) {
            int digit = val & 0xf;
            *p = (digit < 10) ? ('0' + digit) : ('A' + digit - 10);
            p--;
            val >>= 4;
        }
    }

    p++;
    printstr(p, (buf + sizeof(buf) - p));
}

extern uint64_t get_cycles(void);
extern uint64_t get_instret(void);

// uf8
#if 1
typedef uint8_t uf8;

/* Decode uf8 to uint32_t */
static uint32_t uf8_decode(uf8 b)
{
    uint32_t mantissa = b & 0x0F;
    uint8_t exponent = b >> 4;
    uint32_t offset = ((1U << exponent) - 1) << 4;
    return (mantissa << exponent) + offset;
}

/* bitwise clz */
static inline unsigned clz_bitwise(uint32_t x)
{
    unsigned n = 32;
    if (x & 0xFFFF0000) {
        n -= 16;
        x >>= 16;
    }
    if (x & 0xFF00) {
        n -= 8;
        x >>= 8;
    }
    if (x & 0xF0) {
        n -= 4;
        x >>= 4;
    }
    if (x & 0xC) {
        n -= 2;
        x >>= 2;
    }
    if (x & 0x2) {
        n -= 1;
        x >>= 1;
    }
    if (x & 0x1) {
        n -= 1;
    }
    return n;
}

static uf8 uf8_encode(uint32_t value)
{
    /* Use CLZ for fast exponent calculation */
    if (value < 16)
        return value;

    /* Find appropriate exponent using CLZ hint */
    int lz = clz_bitwise(value);
    int msb = 31 - lz;

    /* Start from a good initial guess */
    uint8_t exponent = 0;
    uint32_t overflow = 0;

    if (msb >= 5) {
        /* Estimate exponent - the formula is empirical */
        exponent = msb - 4;
        if (exponent > 15)
            exponent = 15;

        /* Calculate overflow for estimated exponent */
        for (uint8_t e = 0; e < exponent; e++)
            overflow = (overflow << 1) + 16;

        /* Adjust if estimate was off */
        while (exponent > 0 && value < overflow) {
            overflow = (overflow - 16) >> 1;
            exponent--;
        }
    }

    /* Find exact exponent */
    while (exponent < 15) {
        uint32_t next_overflow = (overflow << 1) + 16;
        if (value < next_overflow)
            break;
        overflow = next_overflow;
        exponent++;
    }

    uint8_t mantissa = (value - overflow) >> exponent;

    if (mantissa > 15)
        mantissa = 15;  // The uf8 max is 0xFF

    return (exponent << 4) + mantissa;
    // Math Formula is Plus.
    // If use plus will ignore the overflow result.
}
#endif

int main(void)
{
    uf8 test_values_uf8_decode[] = {0x00, 0x01, 0x0F, 0x10, 0x1F, 0x20,
                                    0x2F, 0x30, 0x3F, 0xF0, 0xFF};
    uint32_t expect_values_uf8_decode[] = {0,   1,   15,  16,     46,     48,
                                           108, 112, 232, 524272, 1015792};

    uint32_t test_values_uf8_encode[] = {
        0x00000000, 0x00000001, 0x0000000F, 0x00000010, 0x00000100, 0x00001000,
        0x00010000, 0x00020000, 0x00040000, 0x00080000, 0x000F7FF0, 0x000FFFFF};

    uint8_t expect_values_uf8_encode[] = {0x00, 0x01, 0x0F, 0x10, 0x41, 0x80,
                                          0xC0, 0xD0, 0xE0, 0xF0, 0xFF, 0xFF};

    uint64_t start_cycles, end_cycles, cycles_elapsed;
    // uint64_t start_instret, end_instret, instret_elapsed;

    TEST_LOGGER("\n=== uf8 Tests ===\n");

    TEST_LOGGER("\n=== uf8 decode ===\n\n");
    start_cycles = get_cycles();
    // start_instret = get_instret();

    for (unsigned long i = 0;
         i < sizeof(test_values_uf8_decode) / sizeof(test_values_uf8_decode[0]);
         i++) {
        uint32_t decoded = uf8_decode(test_values_uf8_decode[i]);
        // TEST_LOGGER("b=0x");
        // print_hex(test_values_uf8_decode[i]);
        // TEST_LOGGER(" -> decoded=");
        // print_dec(decoded);
        // TEST_LOGGER(" (expected=");
        // print_dec(expect_values_uf8_decode[i]);
        // TEST_LOGGER(")\n");
        if (decoded != expect_values_uf8_decode[i]) {
            TEST_LOGGER("wrong\n");
            return 1;
        } else {
            TEST_LOGGER("correct\n");
        }
    }

    end_cycles = get_cycles();
    // end_instret = get_instret();
    cycles_elapsed = end_cycles - start_cycles;
    // instret_elapsed = end_instret - start_instret;

    TEST_LOGGER("Cycles:");
    print_dec((unsigned long) cycles_elapsed);
    // TEST_LOGGER("  Instructions: ");
    // print_dec((unsigned long) instret_elapsed);

    TEST_LOGGER("\n=== uf8 encode ===\n\n");
    start_cycles = get_cycles();
    // start_instret = get_instret();

    for (unsigned long i = 0;
         i < sizeof(test_values_uf8_encode) / sizeof(test_values_uf8_encode[0]);
         i++) {
        uf8 encoded = uf8_encode(test_values_uf8_encode[i]);
        // TEST_LOGGER("value=0x");
        // print_hex(test_values_uf8_encode[i]);
        // TEST_LOGGER(" -> uf8=0x");
        // print_hex(encoded);
        // TEST_LOGGER(" (expect 0x");
        // print_hex(expect_values_uf8_encode[i]);
        // TEST_LOGGER(")\n");
        if (encoded != expect_values_uf8_encode[i]) {
            TEST_LOGGER("wrong\n");
            return 1;
        } else {
            TEST_LOGGER("correct\n");
        }
    }

    end_cycles = get_cycles();
    // end_instret = get_instret();
    cycles_elapsed = end_cycles - start_cycles;
    // instret_elapsed = end_instret - start_instret;

    TEST_LOGGER("Cycles:");
    print_dec((unsigned long) cycles_elapsed);
    // TEST_LOGGER("  Instructions: ");
    // print_dec((unsigned long) instret_elapsed);

    TEST_LOGGER("\n=== All Tests Completed ===\n");
    return 0;
}