#include <libfdt.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>

#include "fdt.h"
#include "utils.h"

const struct fdt_match machine_match[] = {
    {.compatible = "apple,s5l8960x", .data = (void*)0x8960 },
    {.compatible = "apple,t7000", .data = (void*)0x7000 },
    {.compatible = "apple,t7001", .data = (void*)0x7001 },
    {.compatible = "apple,s8000", .data = (void*)0x8000 },
    {.compatible = "apple,s8001", .data = (void*)0x8001 },
    {.compatible = "apple,s8003", .data = (void*)0x8003 },
    {.compatible = "apple,t8010", .data = (void*)0x8010 },
    {.compatible = "apple,t8011", .data = (void*)0x8011 },
    {.compatible = "apple,t8012", .data = (void*)0x8012 },
    {.compatible = "apple,t8015", .data = (void*)0x8015 },
};

int main(void)
{
    void *fdt;

    if (hlt_load_fdt(&fdt))
        bail("load fdt failed!\n");

    const void *data;

    if (!hlt_fdt_match_compatible(fdt, 0, machine_match, &data))
    {
        bail("unable to identify machine\n");
    }

    printf("Current chip_id: %lx\n", (uintptr_t)data);

    printf("HoolockLinux Test -- SUCCESS\n");
    return 0;
}
