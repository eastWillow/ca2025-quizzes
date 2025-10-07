#include <assert.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    uint16_t bits;
} bf16_t;

static inline bf16_t f32_to_bf16(float val)
{
    uint32_t f32bits;
    memcpy(&f32bits, &val, sizeof(float));
    if (((f32bits >> 23) & 0xFF) == 0xFF)
        return (bf16_t) {.bits = (f32bits >> 16) & 0xFFFF};
    f32bits += ((f32bits >> 16) & 1) + 0x7FFF;
    return (bf16_t) {.bits = f32bits >> 16};
}

int main(void)
{
    float test_data[] = {
        0.0f,        -0.0f, INFINITY, -INFINITY, NAN, 1.0f, 0.5f, 2.0f,
        1.0117188f,   // round up   to 1.015625f
        1.0039063f,   // round down to 1.0f
        1.0112305f,   // round down to 1.0078125f
        -1.0117188f,  // round up
        -1.0112305f   // round down
    };
    uint32_t expect_bits_data[] = {
        0x00000000, 0x80000000, 0x7F800000, 0xFF800000,
        0x7FC00000, 0x3F800000, 0x3F000000, 0x40000000,
        0x3F818000,  // round up
        0x3F808000,  // round down
        0x3F817000,  // round down
        0xBF818000,  // round up
        0xBF817000   // round down
    };

    bf16_t expect_bf16_data[] = {
        0x0,    0x8000, 0x7F80, 0xFF80, 0x7FC0, 0x3F80, 0x3F00, 0x4000,
        0x3F82,  // round up
        0x3F80,  // round down
        0x3F81,  // round down
        0xBF82,  // round up
        0xBF81,  // round down
    };

    for (int i = 0; i < 12; i++) {
        float x = test_data[i];
        uint32_t f32bits;
        memcpy(&f32bits, &x, sizeof(float));
        printf("test :%d\n", i);
        printf(
            "    input = %f, input actial bits = 0x%X, expect input bits = "
            "0x%X \n",
            x, f32bits, expect_bits_data[i]);
        assert(f32bits == expect_bits_data[i]);

        bf16_t actual_bf16 = f32_to_bf16(x);
        printf("    bf16_bits = 0x%X, expect = 0x%X \n", actual_bf16.bits,
               expect_bf16_data[i].bits);
        assert(actual_bf16.bits == expect_bf16_data[i].bits);
    }

    printf("All test cases passed!\n");
    return 0;
}