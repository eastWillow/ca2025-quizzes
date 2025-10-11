/*
gcc -O0 -fprofile-arcs -ftest-coverage bf16_comp.c -o bf16_comp &&\
./bf16_comp &&\
gcov -o bf16_comp bf16_comp.c &&\
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

#define BF16_SIGN_MASK 0x8000U
#define BF16_EXP_MASK 0x7F80U
#define BF16_MANT_MASK 0x007FU

#define BF16_ZERO ((bf16_t) {.bits = 0x0000})
#define BF16_NAN ((bf16_t) {.bits = 0x7FC0})
#define BF16_POS_INF ((bf16_t) {.bits = 0x7F80})
#define BF16_NEG_INF ((bf16_t) {.bits = 0xFF80})

static inline bool bf16_eq(bf16_t a, bf16_t b)
{
    uint32_t s0 = a.bits & BF16_EXP_MASK;
    uint32_t s1 = a.bits & BF16_MANT_MASK;
    if (((s0) == BF16_EXP_MASK) && (s1))
        return false;

    uint32_t s2 = b.bits & BF16_EXP_MASK;
    uint32_t s3 = b.bits & BF16_MANT_MASK;
    if (((s2) == BF16_EXP_MASK) && (s3))
        return false;

    uint32_t s4 = a.bits & 0x7FFF;
    uint32_t s5 = b.bits & 0x7FFF;
    if (!(s4) && !(s5))
        return true;

    return a.bits == b.bits;
}

static inline bool bf16_lt(bf16_t a, bf16_t b)  // a < b
{
    uint32_t s0 = a.bits & BF16_EXP_MASK;
    uint32_t s1 = a.bits & BF16_MANT_MASK;
    if (((s0) == BF16_EXP_MASK) && (s1))
        return false;

    uint32_t s2 = b.bits & BF16_EXP_MASK;
    uint32_t s3 = b.bits & BF16_MANT_MASK;
    if (((s2) == BF16_EXP_MASK) && (s3))
        return false;

    uint32_t s4 = a.bits & 0x7FFF;
    uint32_t s5 = b.bits & 0x7FFF;
    if (!(s4) && !(s5))
        return false;

    uint32_t sign_a = (a.bits >> 15) & 1;  // s6
    uint32_t sign_b = (b.bits >> 15) & 1;  // s7
    if (sign_a != sign_b)
        return sign_b < sign_a;

    return sign_a ? b.bits < a.bits : a.bits < b.bits;
}

static inline bool bf16_gt(bf16_t a, bf16_t b)  // a > b
{
    return bf16_lt(b, a);
}

int main(void)
{
    bf16_t test_a_data[] = {
        0x0000,        // 1. +0 vs +0
        0x8000,        // 2. -0 vs +0
        0x3F80,        // 3. +1 vs +1
        0x3F80,        // 4. +1 vs +2
        0x4000,        // 5. +2 vs +1
        0x3F80,        // 6. +1 vs -1
        0xC000,        // 7. -2 vs -1
        0xBF80,        // 8. -1 vs -2
        BF16_POS_INF,  // 9. +Inf vs +Inf
        BF16_POS_INF,  // 10. +Inf vs -Inf
        BF16_NEG_INF,  // 11. -Inf vs +Inf
        BF16_NAN,      // 12. NaN vs +1.0
        0x3F80,        // 13. +1.0 vs NaN
    };

    bf16_t test_b_data[] = {
        0x0000,        // 1. +0 vs +0
        0x0000,        // 2. -0 vs +0
        0x3F80,        // 3. +1 vs +1
        0x4000,        // 4. +1 vs +2
        0x3F80,        // 5. +2 vs +1
        0xBF80,        // 6. +1 vs -1
        0xBF80,        // 7. -2 vs -1
        0xC000,        // 8. -1 vs -2
        BF16_POS_INF,  // 9. +Inf vs +Inf
        BF16_NEG_INF,  // 10. +Inf vs -Inf
        BF16_POS_INF,  // 11. -Inf vs +Inf
        0x3F80,        // 12. NaN vs +1.0
        BF16_NAN,      // 13. +1.0 vs NaN
    };

    bool expect_eq_data[] = {
        true,   // 1. +0 == +0
        true,   // 2. -0 == +0
        true,   // 3. +1 == +1
        false,  // 4. +1 != +2
        false,  // 5. +2 != +1
        false,  // 6. +1 != -1
        false,  // 7. -2 != -1
        false,  // 8. -1 != -2
        true,   // 9. +Inf == +Inf
        false,  // 10. +Inf != -Inf
        false,  // 11. -Inf != +Inf
        false,  // 12. NaN != +1.0
        false,  // 13. +1.0 vs NaN
    };

    bool expect_lt_data[] = {
        false,  // 1. +0 < +0
        false,  // 2. -0 < +0 (treated equal)
        false,  // 3. +1 < +1
        true,   // 4. +1 < +2
        false,  // 5. +2 < +1
        false,  // 6. +1 < -1
        true,   // 7. -2 < -1
        false,  // 8. -1 < -2
        false,  // 9. +Inf < +Inf
        false,  // 10. +Inf < -Inf
        true,   // 11. -Inf < +Inf
        false,  // 12. NaN < +1.0
        false,  // 13. +1.0 vs NaN
    };

    bool expect_gt_data[] = {
        false,  // 1. +0 > +0
        false,  // 2. -0 > +0
        false,  // 3. +1 > +1
        false,  // 4. +1 > +2
        true,   // 5. +2 > +1
        true,   // 6. +1 > -1
        false,  // 7. -2 > -1
        true,   // 8. -1 > -2
        false,  // 9. +Inf > +Inf
        true,   // 10. +Inf > -Inf
        false,  // 11. -Inf > +Inf
        false,  // 12. NaN > +1.0
        false,  // 13. +1.0 vs NaN
    };


    for (int i = 0; i < sizeof(test_a_data) / sizeof(bf16_t); i++) {
        bf16_t a = test_a_data[i];
        bf16_t b = test_b_data[i];

        printf("Now Test: %2d,", i);
        printf("a bf16: 0x%X,", (a.bits));
        printf("b bf16: 0x%X,", (b.bits));
        printf("bf16_eq: %d expect: %d, ", bf16_eq(a, b), expect_eq_data[i]);
        assert(bf16_eq(a, b) == expect_eq_data[i]);
        printf("bf16_lt: %d expect: %d, ", bf16_lt(a, b), expect_lt_data[i]);
        assert(bf16_lt(a, b) == expect_lt_data[i]);
        printf("bf16_gt: %d expect: %d\n", bf16_gt(a, b), expect_gt_data[i]);
        assert(bf16_gt(a, b) == expect_gt_data[i]);
    }

    printf("All test cases passed!\n");
    return 0;
}