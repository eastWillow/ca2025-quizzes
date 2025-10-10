/*
gcc -O0 -fprofile-arcs -ftest-coverage bf16_mul.c -o bf16_mul &&\
./bf16_mul &&\
gcov -o bf16_mul bf16_mul.c &&\
lcov --capture --directory . --output-file coverage.info &&\
genhtml coverage.info --output-directory html_report
*/

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    uint16_t bits;
} bf16_t;

#define BF16_EXP_MASK 0x7F80U
#define BF16_EXP_BIAS 127

#define BF16_NAN() ((bf16_t) {.bits = 0x7FC0})

static inline bf16_t bf16_mul(bf16_t a, bf16_t b)
{
    uint16_t sign_a = (a.bits >> 15) & 1;
    uint16_t sign_b = (b.bits >> 15) & 1;
    int16_t exp_a = ((a.bits >> 7) & 0xFF);
    int16_t exp_b = ((b.bits >> 7) & 0xFF);
    uint16_t mant_a = a.bits & 0x7F;
    uint16_t mant_b = b.bits & 0x7F;

    uint16_t result_sign = sign_a ^ sign_b;

    if (exp_a == 0xFF) {
        if (mant_a)
            return a;
        if (!exp_b && !mant_b)
            return BF16_NAN();
        return (bf16_t) {.bits = (result_sign << 15) | 0x7F80};
    }
    if (exp_b == 0xFF) {
        if (mant_b)
            return b;
        if (!exp_a && !mant_a)
            return BF16_NAN();
        return (bf16_t) {.bits = (result_sign << 15) | 0x7F80};
    }
    if ((!exp_a && !mant_a) || (!exp_b && !mant_b))
        return (bf16_t) {.bits = result_sign << 15};

    int16_t exp_adjust = 0;
    if (!exp_a) {
        while (!(mant_a & 0x80)) {
            mant_a <<= 1;
            exp_adjust--;
        }
        exp_a = 1;
    } else
        mant_a |= 0x80;
    if (!exp_b) {
        while (!(mant_b & 0x80)) {
            mant_b <<= 1;
            exp_adjust--;
        }
        exp_b = 1;
    } else
        mant_b |= 0x80;

    uint32_t result_mant = (uint32_t) mant_a * mant_b;

    int32_t result_exp = (int32_t) exp_a + exp_b - BF16_EXP_BIAS + exp_adjust;

    if (result_mant & 0x8000) {
        result_mant = (result_mant >> 8) & 0x7F;
        result_exp++;
    } else
        result_mant = (result_mant >> 7) & 0x7F;

    if (result_exp >= 0xFF)
        return (bf16_t) {.bits = (result_sign << 15) | 0x7F80};
    if (result_exp <= 0) {
        if (result_exp < -6)
            return (bf16_t) {.bits = result_sign << 15};
        result_mant >>= (1 - result_exp);
        result_exp = 0;
    }

    return (bf16_t) {.bits = (result_sign << 15) | ((result_exp & 0xFF) << 7) |
                             (result_mant & 0x7F)};
}

static inline float bf16_to_f32(bf16_t val)
{
    uint32_t f32bits = ((uint32_t) val.bits) << 16;
    float result;
    memcpy(&result, &f32bits, sizeof(float));
    return result;
}

int main(void)
{
    bf16_t test_a_data[] = {0x0000, 0x8000, 0x8000, 0x0000, 0x7F80, 0xFF80,
                            0x7FC0, 0x3F80, 0xBF80, 0x0000, 0x0000, 0xBF80,
                            0x3F81, 0xBF82, 0xBF81, 0x7F80, 0x3F80, 0x0040,
                            0x3F80, 0x3FC0, 0x7F7F, 0x0080, 0x0000, 0x0000};

    bf16_t test_b_data[] = {0x0000, 0x8000, 0x0000, 0x8000, 0x7F80, 0xFF80,
                            0x7FC0, 0x0000, 0x0000, 0x3F80, 0xBF80, 0x3F80,
                            0x3F81, 0xBF82, 0xBF81, 0x0000, 0x7F80, 0x3F80,
                            0x0040, 0x3FC0, 0x7F7F, 0x0080, 0x7F88, 0x7F80};

    bf16_t expect_mul_data[] = {0x0000, 0x0000, 0x8000, 0x8000, 0x7F80, 0x7F80,
                                0x7FC0, 0x0000, 0x8000, 0x0000, 0x8000, 0xBF80,
                                0x3F82, 0x3F84, 0x3F82, 0x7FC0, 0x7F80, 0x0000,
                                0x0000, 0x4010, 0x7F80, 0x0000, 0x7F88, 0x7FC0};

    for (int i = 0; i < 24; i++) {
        bf16_t a = test_a_data[i];
        bf16_t b = test_b_data[i];
        uint32_t f32bits;
        float val;

        printf("Now Test: %02d ", i);
        printf("bf16_a: 0x%04X ", a.bits);
        printf("bf16_b: 0x%04X ", b.bits);
        printf("bf16_mul: 0x%04X ", bf16_mul(a, b).bits);
        printf("expect_mul: 0x%04X ", expect_mul_data[i].bits);

        printf("f32_a: %+e ", bf16_to_f32(a));
        printf("f32_b: %+e ", bf16_to_f32(b));
        val = bf16_to_f32(a) * bf16_to_f32(b);
        memcpy(&f32bits, &val, sizeof(float));
        printf("f32_mul: %+f ", val);
        printf("f32_mul: 0x%08X\n", f32bits);
        assert(bf16_mul(a, b).bits == expect_mul_data[i].bits);
    }

    printf("All test cases passed!\n");
    return 0;
}