#include <stdint.h>

extern void printstr(char *ptr, unsigned long length);
extern void print_dec(unsigned long val);
extern void print_char(unsigned long val);

#define TEST_OUTPUT(msg, length) printstr(msg, length)

#define TEST_LOGGER(msg)                     \
    {                                        \
        char _msg[] = msg;                   \
        TEST_OUTPUT(_msg, sizeof(_msg) - 1); \
    }

/* Bare metal memcpy implementation */
void *memcpy(void *dest, const void *src, unsigned long n)
{
    uint8_t *d = (uint8_t *) dest;
    const uint8_t *s = (const uint8_t *) src;
    while (n--)
        *d++ = *s++;
    return dest;
}

typedef uint64_t ticks;
static inline ticks getticks(void)
{
    uint64_t result;
    uint32_t l, h, h2;
    asm volatile(
        "rdcycleh %0\n"
        "rdcycle %1\n"
        "rdcycleh %2\n"
        "sub %0, %0, %2\n"
        "seqz %0, %0\n"
        "sub %0, zero, %0\n"
        "and %1, %1, %0\n"
        : "=r"(h), "=r"(l), "=r"(h2));
    result = (((uint64_t) h) << 32) | ((uint64_t) l);
    return result;
}

static uint64_t mul32(uint32_t a, uint32_t b)
{
    uint64_t r = 0;
    for (int i = 0; i < 32; i++) {
        if (b & (1U << i))
            r += (uint64_t) a << i;
    }
    return r;
}

static const uint32_t rsqrt_table[32] = {
    65536, 46341, 32768, 23170, 16384, /* 2^0 to 2^4 */
    11585, 8192,  5793,  4096,  2896,  /* 2^5 to 2^9 */
    2048,  1448,  1024,  724,   512,   /* 2^10 to 2^14 */
    362,   256,   181,   128,   90,    /* 2^15 to 2^19 */
    64,    45,    32,    23,    16,    /* 2^20 to 2^24 */
    11,    8,     6,     4,     3,     /* 2^25 to 2^29 */
    2,     1                           /* 2^30, 2^31 */
};

static int clz(uint32_t x)
{
    if (!x)
        return 32; /* Special case: no bits set*/
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

uint32_t fast_rsqrt(uint32_t x)
{
    if (x == 0)
        return 0xFFFFFFFF; /* Infinity representation */
    if (x == 1)
        return 65536; /* Exact Result for x = 1*/

    // Step 1
    int exp = 31 - clz(x);

    // Step 2
    uint32_t y = rsqrt_table[exp];

    // Step 3
    if (x > (1u << exp)) {
        uint32_t y_next = (exp < 31) ? rsqrt_table[exp + 1] : 0;
        uint32_t delta = y - y_next;
        uint32_t frac =
            (uint32_t) ((((uint64_t) x - (1UL << exp)) << 16) >> exp);
        y -= (uint32_t) (mul32(delta, frac) >> 16);
    }

    // Step 4
    for (int iter = 0; iter < 2; iter++) {
        uint32_t y2 = (uint32_t) mul32(y, y);
        uint32_t xy2 = (uint32_t) (mul32(x, y2) >> 16);
        y = (uint32_t) (mul32(y, (3u << 16) - xy2) >> 17);
    }

    return y;
}

int main(void)
{
    uint32_t test_values[] = {1, 4, 16, 20, 100, 1024, 65536, 4294967295U};
    uint32_t expect_values[] = {65536, 32768, 16384, 14654, 6553, 2048, 256, 1};

    int num_tests = sizeof(test_values) / sizeof(test_values[0]);

    // printf("x\t\tfast_rsqrt(x)\tapprox sqrt\t math.h
    // \trelative_error(%%)\n");
    // printf("-------------------------------------------------------------\n");

    TEST_LOGGER("x\t\tfast_rsqrt(x)\t expect value\n");
    TEST_LOGGER(
        "-------------------------------------------------------------\n");

    for (int i = 0; i < num_tests; i++) {
        uint32_t x = test_values[i];

        uint32_t y_fixed = fast_rsqrt(x);  // scaled by 2^16

        print_dec(x);
        print_char('\t');
        if (x < 10000000)
            print_char('\t');
        print_dec(y_fixed);
        print_char('\t');
        print_dec(expect_values[i]);
        print_char('\n');

        if (y_fixed != expect_values[i]) {
            TEST_LOGGER("test failed\n");
            return -1;
        }

        // double y_approx = (double) y_fixed / 65536.0;  // convert back to
        // float

        // double y_true = 1.0 / sqrt((double) x);  // math.h reference
        // double rel_err = fabs(y_true - y_approx) / y_true * 100.0;
        // printf("%10u\t%10u\t%.8f\t%.8f\t%.3f%%\n", x, y_fixed, y_approx,
        // y_true,
        //        rel_err);
    }

    TEST_LOGGER("All test pass\n");
    return 0;
}