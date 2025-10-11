/*
gcc -O0 -fprofile-arcs -ftest-coverage bf16_sqrt.c -lm -o bf16_sqrt &&\
./bf16_sqrt &&\
gcov -o bf16_sqrt bf16_sqrt.c &&\
lcov --capture --directory . --output-file coverage.info &&\
genhtml coverage.info --output-directory html_report
*/

#include <assert.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    uint16_t bits;
} bf16_t;

#define BF16_EXP_MASK 0x7F80U
#define BF16_EXP_BIAS 127
#define BF16_POS_INF 0x7F80U

#define BF16_NAN() ((bf16_t) {.bits = 0x7FC0})
#define BF16_ZERO() ((bf16_t) {.bits = 0x0000})

static inline bf16_t bf16_sqrt(bf16_t a)
{
    uint16_t sign = (a.bits >> 15) & 1;
    int16_t exp = ((a.bits >> 7) & 0xFF);
    uint16_t mant = a.bits & 0x7F;

    /* Handle special cases */
    if (exp == 0xFF) {
        if (mant)
            return a; /* NaN propagation */
        if (sign)
            return BF16_NAN(); /* sqrt(-Inf) = NaN */
        return a;              /* sqrt(+Inf) = +Inf */
    }

    /* sqrt(0) = 0 (handle both +0 and -0) */
    if (!exp && !mant)
        return BF16_ZERO();

    /* sqrt of negative number is NaN */
    if (sign)
        return BF16_NAN();

    /* Flush denormals to zero */
    if (!exp)
        return BF16_ZERO();

    /* Direct bit manipulation square root algorithm */
    /* For sqrt: new_exp = (old_exp - bias) / 2 + bias */
    int32_t e = exp - BF16_EXP_BIAS;
    int32_t new_exp;

    /* Get full mantissa with implicit 1 */
    mant = 0x80 | mant; /* Range [128, 256) representing [1.0, 2.0) */

    /* Adjust for odd exponents: sqrt(2^odd * m) = 2^((odd-1)/2) * sqrt(2*m) */
    int32_t mask = (e & 1);
    mant <<= mask; /* Double mantissa for odd exponent */
    new_exp = ((e - mask) >> 1) + BF16_EXP_BIAS;

    /* Now m is in range [128, 256) or [256, 512) if exponent was odd */
    /* Binary search for integer square root */
    /* We want result where result^2 = m * 128 (since 128 represents 1.0) */

    uint32_t low = 90;     /* Min sqrt (roughly sqrt(128)) */
    uint32_t high = 256;   /* Max sqrt (roughly sqrt(512)) */
    uint32_t result = 128; /* Default */

    /* Binary search for square root of m */
    while (low <= high) {
        uint32_t mid = (low + high) >> 1;
        uint32_t sq = 0;
        for (int i = 0; i < 32; i++) {
            uint32_t mask = -((mid >> i) & 1);
            // bit=1 , mask=0xFFFFFFFF
            // bit=0 , mask=0x00000000
            sq += (mid << i) & mask;
        }
        sq = sq >> 7;

        if (sq <= mant) {
            result = mid; /* This could be our answer */
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    /* result now contains sqrt(m) * sqrt(128) / sqrt(128) = sqrt(m) */
    /* But we need to adjust the scale */
    /* Since m is scaled where 128=1.0, result should also be scaled same way */

    /* Normalize to ensure result is in [128, 256) */
    if (result >= 256) {
        result >>= 1;
        new_exp++;
    } else if (result < 128) {
        while (result < 128 && new_exp > 1) {
            result <<= 1;
            new_exp--;
        }
    }

    /* Extract 7-bit mantissa (remove implicit 1) */
    uint16_t new_mant = result & 0x7F;

    /* Check for overflow/underflow */
    if (new_exp >= 0xFF)
        return (bf16_t) {.bits = 0x7F80}; /* +Inf */
    if (new_exp <= 0)
        return BF16_ZERO();

    return (bf16_t) {.bits = ((new_exp & 0xFF) << 7) | new_mant};
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
    bf16_t test_a_data[] = {
        {.bits = 0x7FC1},  // NaN
        {.bits = 0x7F80},  // +Inf
        {.bits = 0xFF80},  // -Inf
        {.bits = 0x0000},  // +0
        {.bits = 0x8000},  // -0
        {.bits = 0xB400},  // -0.75
        {.bits = 0x0040},  // Denormal
        {.bits = 0x4000},  // 2.0 (odd exponent)
        {.bits = 0x3F80},  // 1.0 (even exponent)
        {.bits = 0x3e80},  // 0.25
        {.bits = 0x7E80},  // overflow case
        {.bits = 0x0080},  // underflow case
        {.bits = 0x407F},  // 3.984375 result is 255
    };

    bf16_t expect_sqrt_data[] = {
        {.bits = 0x7FC1},  // NaN
        {.bits = 0x7F80},  // +Inf
        {.bits = 0x7FC0},  // sqrt(-Inf) = NaN
        {.bits = 0x0000},  // sqrt(+0) = +0
        {.bits = 0x0000},  // sqrt(-0) = +0
        {.bits = 0x7FC0},  // sqrt(-0.75) = NaN
        {.bits = 0x0000},  // sqrt(denormal) = 0
        {.bits = 0x3FB5},  // sqrt(2.0) ≈ 1.414
        {.bits = 0x3F80},  // sqrt(1.0) = 1.0
        {.bits = 0x3F00},  // sqrt(0.25) = 0.5
        {.bits = 0x5F00},  // overflow → +Inf
        {.bits = 0x2000},  // underflow → 0
        {.bits = 0x3FFF},  // sqrt(3.984375)
    };

    for (int i = 0; i < sizeof(test_a_data) / sizeof(bf16_t); i++) {
        bf16_t a = test_a_data[i];
        uint32_t f32bits;
        float val;

        printf("Now Test: %02d ", i);
        printf("bf16_a: 0x%04X ", a.bits);
        bf16_t actual = bf16_sqrt(a);
        printf("bf16_sqrt: 0x%04X ", actual.bits);
        printf("expect_sqrt: 0x%04X ", expect_sqrt_data[i].bits);

        printf("f32_a: %+e ", bf16_to_f32(a));
        val = sqrtf(bf16_to_f32(a));
        memcpy(&f32bits, &val, sizeof(float));
        printf("f32_sqrt: %+f ", val);
        printf("f32_sqrt: 0x%08X\n", f32bits);
        assert(actual.bits == expect_sqrt_data[i].bits);
    }

    printf("All test cases passed!\n");
    return 0;
}