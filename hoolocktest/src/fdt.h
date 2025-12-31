#ifndef HLT_FDT_H
#define HLT_FDT_H

#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

struct fdt_match {
    const char *compatible;
    void *data;
};

int hlt_load_fdt(void **fdtp);
bool _hlt_fdt_match_compatible(void *fdt, int nodeoffset, const struct fdt_match match_table[], size_t num_of_matches, const void **match_data);

#define hlt_fdt_match_compatible(fdt, nodeoffset, match_table, data) \
    _hlt_fdt_match_compatible(fdt, nodeoffset, match_table, sizeof(match_table)/sizeof(struct fdt_match), data)

#endif
