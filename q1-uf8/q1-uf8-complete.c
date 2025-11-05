#include <assert.h>
#include <stdint.h>
#include <stdio.h>

typedef uint8_t uf8;

/* Decode uf8 to uint32_t */
uint32_t uf8_decode(uf8 b)
{
    uint32_t mantissa = b & 0x0F;
    uint8_t exponent = b >> 4;
    uint32_t offset = ((1U << exponent) - 1) << 4;
    return (mantissa << exponent) + offset;
}

/* bitwise 版 clz */
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

uf8 uf8_encode(uint32_t value)
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

int main(void)
{
    uf8 test_values_uf8_decode[] = {0x00, 0x01, 0x0F, 0x10, 0x1F, 0x20,
                                    0x2F, 0x30, 0x3F, 0xF0, 0xFF};
    uint32_t expect_values_uf8_decode[] = {0,   1,   15,  16,     46,     48,
                                           108, 112, 232, 524272, 1015792};

    for (int i = 0;
         i < sizeof(test_values_uf8_decode) / sizeof(test_values_uf8_decode[0]);
         i++) {
        uint32_t decoded = uf8_decode(test_values_uf8_decode[i]);
        printf("b=0x%02X -> decoded=%u (expected=%u)\n",
               test_values_uf8_decode[i], decoded, expect_values_uf8_decode[i]);
        assert(decoded == expect_values_uf8_decode[i]);
    }

    printf("All uf8_decode test cases passed!\n");

    uint32_t test_values_uf8_encode[] = {
        0x00000000, 0x00000001, 0x0000000F, 0x00000010, 0x00000100, 0x00001000,
        0x00010000, 0x00020000, 0x00040000, 0x00080000, 0x000F7FF0, 0x000FFFFF};

    uint8_t expect_values_uf8_encode[] = {0x00, 0x01, 0x0F, 0x10, 0x41, 0x80,
                                          0xC0, 0xD0, 0xE0, 0xF0, 0xFF, 0xFF};

    for (size_t i = 0;
         i < sizeof(test_values_uf8_encode) / sizeof(test_values_uf8_encode[0]);
         i++) {
        uf8 encoded = uf8_encode(test_values_uf8_encode[i]);
        printf("value=0x%08X -> uf8=0x%02X (expect 0x%02X)\n",
               test_values_uf8_encode[i], encoded, expect_values_uf8_encode[i]);
        assert(encoded == expect_values_uf8_encode[i]);
    }

    printf("All uf8_encode tests passed!\n");

    return 0;
}