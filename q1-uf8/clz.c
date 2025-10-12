/*
gcc -O0 -fprofile-arcs -ftest-coverage clz.c -o clz &&\
./clz &&\
gcov -o clz clz.c &&\
lcov --capture --directory . --output-file coverage.info &&\
genhtml coverage.info --output-directory html_report
*/
#include <assert.h>
#include <stdint.h>
#include <stdio.h>

/* 原始迴圈版 clz */
static inline unsigned clz_loop(uint32_t x)
{
    int n = 32, c = 16;
    do {
        uint32_t y = x >> c;
        if (y) {
            n -= c;
            x = y;
        }
        c >>= 1;
    } while (c);
    return n - x;
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

int main(void)
{
    /* 測試一些基本邊界值 */
    uint32_t test_values[] = {0x00000000, 0x00000001, 0x00000002, 0x0000000F,
                              0x00000010, 0x00000080, 0x0000FFFF, 0x00FF0000,
                              0x08000000, 0x10000000, 0x80000000, 0xFFFFFFFF};

    int num_tests = sizeof(test_values) / sizeof(test_values[0]);

    for (int i = 0; i < num_tests; i++) {
        uint32_t x = test_values[i];
        unsigned a = clz_loop(x);
        unsigned b = clz_bitwise(x);
        printf("x = 0x%08X, clz_loop = %u, clz_bitwise = %u\n", x, a, b);
        assert(a == b);
    }

    /* 測試隨機值 */
    for (uint32_t x = 1; x != 0; x = x << 1) {  // 單一 bit
        unsigned a = clz_loop(x);
        unsigned b = clz_bitwise(x);
        assert(a == b);
    }

    printf("All test cases passed!\n");
    return 0;
}