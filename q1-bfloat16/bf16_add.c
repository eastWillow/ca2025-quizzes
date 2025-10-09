// gcc bf16_add.c -o bf16_add.o -lm && ./bf16_add.o

#include <assert.h>
// #include <fenv.h> //need -lm
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    uint16_t bits;
} bf16_t;

#define BF16_SIGN_MASK 0x8000U
#define BF16_ZERO() ((bf16_t) {.bits = 0x0000})
#define BF16_NAN() ((bf16_t) {.bits = 0x7FC0})

static inline float bf16_to_f32(bf16_t val)
{
    uint32_t f32bits = ((uint32_t) val.bits) << 16;
    float result;
    memcpy(&result, &f32bits, sizeof(float));
    return result;
}

static inline bf16_t f32_to_bf16(float val)
{
    uint32_t f32bits;
    memcpy(&f32bits, &val, sizeof(float));
    if (((f32bits >> 23) & 0xFF) == 0xFF)
        return (bf16_t) {.bits = (f32bits >> 16) & 0xFFFF};
    f32bits += ((f32bits >> 16) & 1) + 0x7FFF;
    return (bf16_t) {.bits = f32bits >> 16};
}

static inline bf16_t bf16_add(bf16_t a, bf16_t b)
{
    uint16_t sign_a = (a.bits >> 15) & 1;
    uint16_t sign_b = (b.bits >> 15) & 1;
    int16_t exp_a = ((a.bits >> 7) & 0xFF);
    int16_t exp_b = ((b.bits >> 7) & 0xFF);
    uint16_t mant_a = a.bits & 0x7F;
    uint16_t mant_b = b.bits & 0x7F;

    if (exp_a == 0xFF) {
        if (mant_a)
            return a;
        if (exp_b == 0xFF)
            return (mant_b || sign_a == sign_b) ? b : BF16_NAN();
        return a;
    }
    if (exp_b == 0xFF)
        return b;
    if (!exp_a && !mant_a) {
        if (!exp_b && !mant_b) {
            if (sign_a != sign_b)
                return BF16_ZERO();
            else
                return a;
        } else
            return b;
    }
    if (!exp_b && !mant_b)
        return a;
    if (exp_a)
        mant_a |= 0x80;
    if (exp_b)
        mant_b |= 0x80;

    int16_t exp_diff = exp_a - exp_b;
    uint16_t result_sign;
    int16_t result_exp;
    uint32_t result_mant;

    if (exp_diff > 0) {
        result_exp = exp_a;
        if (exp_diff > 8)
            return a;
        mant_b >>= exp_diff;
    } else if (exp_diff < 0) {
        result_exp = exp_b;
        if (exp_diff < -8)
            return b;
        mant_a >>= -exp_diff;
    } else {
        result_exp = exp_a;
    }

    if (sign_a == sign_b) {
        result_sign = sign_a;
        result_mant = (uint32_t) mant_a + mant_b;

        if (result_mant & 0x100) {
            result_mant >>= 1;
            if (++result_exp >= 0xFF)
                return (bf16_t) {.bits = (result_sign << 15) | 0x7F80};
        }
    } else {
        if (mant_a >= mant_b) {
            result_sign = sign_a;
            result_mant = mant_a - mant_b;
        } else {
            result_sign = sign_b;
            result_mant = mant_b - mant_a;
        }

        if (!result_mant) {
            return BF16_ZERO();
        }
        while (!(result_mant & 0x80)) {
            result_mant <<= 1;
            if (--result_exp <= 0) {
                return BF16_ZERO();
            }
        }
    }
    return (bf16_t) {
        .bits = (result_sign << 15) | ((result_exp & 0xFF) << 7) |
                (result_mant & 0x7F),
    };
}

static inline bf16_t bf16_sub(bf16_t a, bf16_t b)
{
    b.bits ^= BF16_SIGN_MASK;
    return bf16_add(a, b);
}

int main(void)
{
    bf16_t test_a_data[] = {0x0000, 0x8000, 0x8000, 0x0000, 0x7F80,
                            0xFF80, 0x7FC0, 0x3F80, 0xBF80, 0x0000,
                            0x0000, 0xBF80, 0x3F81, 0xBF82, 0xBF81};

    bf16_t test_b_data[] = {0x0000, 0x8000, 0x0000, 0x8000, 0x7F80,
                            0xFF80, 0x7FC0, 0x0000, 0x0000, 0x3F80,
                            0xBF80, 0x3F80, 0x3F81, 0xBF82, 0xBF81};

    bf16_t expect_add_data[] = {0x0000, 0x8000, 0x0000, 0x0000, 0x7F80,
                                0xFF80, 0x7FC0, 0x3F80, 0xBF80, 0x3F80,
                                0xBF80, 0x0000, 0x4001, 0xC002, 0xC001};

    bf16_t expect_sub_data[] = {0x0000, 0x0000, 0x8000, 0x0000, 0x7FC0,
                                0x7FC0, 0x7FC0, 0x3F80, 0xBF80, 0xBF80,
                                0x3F80, 0xC000, 0x0000, 0x0000, 0x0000};

    // switch (fegetround()) {
    // case FE_TONEAREST:
    //     printf("roundTiesToEven\n");
    //     break;
    // case FE_UPWARD:
    //     printf("roundTowardPositive\n");
    //     break;
    // case FE_DOWNWARD:
    //     printf("roundTowardNegative\n");
    //     break;
    // case FE_TOWARDZERO:
    //     printf("roundTowardZero\n");
    //     break;
    // }

    for (int i = 0; i < 15; i++) {
        bf16_t a = test_a_data[i];
        bf16_t b = test_b_data[i];

        printf("Now Test: %d ", i);
        printf("bf16_add: 0x%X ", bf16_add(a, b).bits);
        printf("bf16_sub: 0x%X ", bf16_sub(a, b).bits);
        printf("f32_add: %+f ", bf16_to_f32(a) + bf16_to_f32(b));
        printf("f32_sub: %+f\n", bf16_to_f32(a) - bf16_to_f32(b));
        assert(bf16_add(a, b).bits == expect_add_data[i].bits);
        assert(bf16_sub(a, b).bits == expect_sub_data[i].bits);
    }

    printf("All test cases passed!\n");
    return 0;
}