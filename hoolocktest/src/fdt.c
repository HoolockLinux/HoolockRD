#include "fdt.h"
#include "utils.h"
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <libfdt.h>

#define FDT_PATH "/sys/firmware/fdt"
#define FDT_MAX_SIZE 2097152

int hlt_load_fdt(void **fdtp)
{
    FILE *f = fopen(FDT_PATH, "rb");
    if (!f)
        bail("could not open fdt\n");

    struct stat st;
    if (stat(FDT_PATH, &st))
        bail("could not fstat fdt\n");

    *fdtp = malloc(st.st_size);
    if (!*fdtp)
        bail("could not allocate memory\n");

    off_t rd = fread(*fdtp, 1, st.st_size, f);

    if (rd != st.st_size)
        bail("could not read all of fdt %zd %zu\n", rd, st.st_size);

    if (!*fdtp)
        bail("map fdt failed\n");

    if (fdt_check_full(*fdtp, st.st_size))
        bail("fdt check failed!\n");

    return 0;
}

bool _hlt_fdt_match_compatible(void *fdt, int nodeoffset, const struct fdt_match match_table[], size_t num_of_matches, const void **match_data)
{
    for (uint8_t i = 0; i < num_of_matches; i++) {
        int retval = fdt_node_check_compatible(fdt, nodeoffset, match_table[i].compatible);

        if (retval < 0)
            return false;

        if (retval)
            continue;

        if (match_data)
            *match_data = match_table[i].data;
        return true;
    }
    return false;
}
