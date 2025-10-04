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

int main(void)
{
    uf8 test_values[] = {0x00, 0x01, 0x0F, 0x10, 0x1F, 0x20,
                         0x2F, 0x30, 0x3F, 0xF0, 0xFF};
    uint32_t expect_values[] = {0,   1,   15,  16,     46,     48,
                                108, 112, 232, 524272, 1015792};
    int n = sizeof(test_values) / sizeof(test_values[0]);

    for (int i = 0; i < n; i++) {
        uint32_t decoded = uf8_decode(test_values[i]);
        printf("b=0x%02X -> decoded=%u (expected=%u)\n", test_values[i],
               decoded, expect_values[i]);
        assert(decoded == expect_values[i]);
    }

    printf("All uf8_decode test cases passed!\n");
    return 0;
}