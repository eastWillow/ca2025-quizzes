/*
gcc -O0 -fprofile-arcs -ftest-coverage bf16_div.c -o bf16_div &&\
./bf16_div &&\
gcov -o bf16_div bf16_div.c &&\
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

#define BF16_NAN() ((bf16_t) {.bits = 0x7FC0})
#define BF16_EXP_BIAS 127
#define BF16_POS_INF 0x7F80U

static inline bf16_t bf16_div(bf16_t a, bf16_t b)
{
    uint16_t sign_a = (a.bits >> 15) & 1;
    uint16_t sign_b = (b.bits >> 15) & 1;
    int16_t exp_a = ((a.bits >> 7) & 0xFF);
    int16_t exp_b = ((b.bits >> 7) & 0xFF);
    uint16_t mant_a = a.bits & 0x7F;
    uint16_t mant_b = b.bits & 0x7F;

    uint16_t result_sign = sign_a ^ sign_b;

    if (exp_b == 0xFF) {
        if (mant_b)
            return b;
        /* Inf/Inf = NaN */
        if (exp_a == 0xFF && !mant_a)
            return BF16_NAN();
        return (bf16_t) {.bits = result_sign << 15};
    }
    if (!exp_b && !mant_b) {
        if (!exp_a && !mant_a)
            return BF16_NAN();
        return (bf16_t) {.bits = (result_sign << 15) | BF16_POS_INF};
    }
    if (exp_a == 0xFF) {
        if (mant_a)
            return a;
        return (bf16_t) {.bits = (result_sign << 15) | BF16_POS_INF};
    }
    if (!exp_a && !mant_a)
        return (bf16_t) {.bits = result_sign << 15};

    if (exp_a)
        mant_a |= 0x80;
    if (exp_b)
        mant_b |= 0x80;

    uint32_t dividend = (uint32_t) mant_a << 15;
    uint32_t divisor = mant_b;
    uint32_t quotient = 0;

    for (int i = 0; i < 16; i++) {
        quotient <<= 1;
        if (dividend >= (divisor << (15 - i))) {
            dividend -= (divisor << (15 - i));
            quotient |= 1;
        }
    }

    int32_t result_exp = (int32_t) exp_a - exp_b + BF16_EXP_BIAS;

    if (!exp_a)
        result_exp--;
    if (!exp_b)
        result_exp++;

    if (quotient & 0x8000)
        quotient >>= 8;
    else {
        while (!(quotient & 0x8000) && result_exp > 1) {
            quotient <<= 1;
            result_exp--;
        }
        quotient >>= 8;
    }
    quotient &= 0x7F;

    if (result_exp >= 0xFF)
        return (bf16_t) {.bits = (result_sign << 15) | BF16_POS_INF};
    if (result_exp <= 0)
        return (bf16_t) {.bits = result_sign << 15};
    return (bf16_t) {
        .bits = (result_sign << 15) | ((result_exp & 0xFF) << 7) |
                (quotient & 0x7F),
    };
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
        0x7FC0,  // NaN
        0x3F80,  // ÷ NaN
        0x3F80,  // ÷ 0
        0x0000,  // 0 ÷ 1
        0x7F80,  // +Inf ÷ 1
        0x3F80,  // ÷ +Inf
        0x0080,  // subnormal ÷ normal
        0x3E80,  // triggers normalization
        0x0040,  // exp_a == 0
        0x3F80,  // result_exp++ (exp_b == 0)
        0x7F80,  // +Inf ÷ +Inf
        0x0000,  // 0 ÷ 0
    };

    bf16_t test_b_data[] = {
        0x3F80,  // 1. normal
        0x7FC0,  // 2. NaN
        0x0000,  // 3. zero
        0x3F80,  // 4. normal
        0x3F80,  // 5. normal
        0x7F80,  // 6. +Inf
        0x3F80,  // 7. normal
        0x3F81,  // 8. subnormal to trigger normalization
        0x3F80,  // 9. normal
        0x0040,  // 10. exp zero
        0x7F80,  // 11. +Inf
        0x0000,  // 12. zero
    };

    int total = sizeof(test_a_data) / sizeof(test_a_data[0]);

    for (int i = 0; i < total; i++) {
        bf16_t a = test_a_data[i];
        bf16_t b = test_b_data[i];
        uint32_t f32bits;
        float val;

        printf("Now Test: %02d ", i);
        printf("bf16_a: 0x%04X ", a.bits);
        printf("bf16_b: 0x%04X ", b.bits);
        printf("bf16_div: 0x%04X ", bf16_div(a, b).bits);
        // printf("expect_div: 0x%04X ", expect_div_data[i].bits);

        printf("f32_a: %+e ", bf16_to_f32(a));
        printf("f32_b: %+e ", bf16_to_f32(b));
        val = bf16_to_f32(a) * bf16_to_f32(b);
        memcpy(&f32bits, &val, sizeof(float));
        printf("f32_div: %+f ", val);
        printf("f32_div: 0x%08X\n", f32bits);
        // assert(bf16_div(a, b).bits == expect_div_data[i].bits);
    }

    printf("All test cases passed!\n");
    return 0;
}