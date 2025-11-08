#include <stdint.h>
#include <stdio.h>
#include "lut_2d_init.h"

uint64_t mul32_2d_lut(uint32_t a, uint32_t b)
{
    uint8_t a0 = (a >> 0) & 0xFF;
    uint8_t a1 = (a >> 8) & 0xFF;
    uint8_t a2 = (a >> 16) & 0xFF;
    uint8_t a3 = (a >> 24) & 0xFF;

    uint8_t b0 = (b >> 0) & 0xFF;
    uint8_t b1 = (b >> 8) & 0xFF;
    uint8_t b2 = (b >> 16) & 0xFF;
    uint8_t b3 = (b >> 24) & 0xFF;

    uint64_t r = 0;
    r += lut_2d[a0][b0];
    r += ((uint64_t) lut_2d[a0][b1] << 8);
    r += ((uint64_t) lut_2d[a0][b2] << 16);
    r += ((uint64_t) lut_2d[a0][b3] << 24);

    r += ((uint64_t) lut_2d[a1][b0] << 8);
    r += ((uint64_t) lut_2d[a1][b1] << 16);
    r += ((uint64_t) lut_2d[a1][b2] << 24);
    r += ((uint64_t) lut_2d[a1][b3] << 32);

    r += ((uint64_t) lut_2d[a2][b0] << 16);
    r += ((uint64_t) lut_2d[a2][b1] << 24);
    r += ((uint64_t) lut_2d[a2][b2] << 32);
    r += ((uint64_t) lut_2d[a2][b3] << 40);

    r += ((uint64_t) lut_2d[a3][b0] << 24);
    r += ((uint64_t) lut_2d[a3][b1] << 32);
    r += ((uint64_t) lut_2d[a3][b2] << 40);
    r += ((uint64_t) lut_2d[a3][b3] << 48);

    return r;
}

// 範例測試
int main()
{
    uint32_t a = 123456789;
    uint32_t b = 987654321;
    uint64_t r = mul32_2d_lut(a, b);
    printf("%llu\n", r);  // 32x32 -> 64-bit 結果
    return 0;
}
