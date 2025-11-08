#include <stdint.h>
#include <stdio.h>

int main()
{
    FILE *fp = fopen("lut_2d_init.h", "w");
    if (!fp)
        return 1;

    fprintf(fp, "uint64_t lut_2d[256][256] = {\n");

    for (int i = 0; i < 256; i++) {
        fprintf(fp, "    {");
        for (int j = 0; j < 256; j++) {
            uint64_t val = (uint64_t) i * (uint64_t) j;
            fprintf(fp, " %llu", val);
            if (j != 255)
                fprintf(fp, ",");
        }
        fprintf(fp, " }");
        if (i != 255)
            fprintf(fp, ",\n");
        else
            fprintf(fp, "\n");
    }

    fprintf(fp, "};\n");
    fclose(fp);

    printf("Output Done lut_2d_init.h\n");
    return 0;
}
