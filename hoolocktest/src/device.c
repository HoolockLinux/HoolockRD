#include <libfdt.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>

#include "fdt.h"
#include "utils.h"
#include "device.h"


static const struct fdt_match machine_match[] = {
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

/*
 * Devices without buttons
 */
static const struct fdt_match not_buttons_match[] = {
    {.compatible = "apple,b238a" }, // HomePod
    {.compatible = "apple,j42d" },  // Apple TV HD
    {.compatible = "apple,j105a" }, // Apple TV 4K
    //{.compatible = "apple,t8012" },  // All T2
};

/*
 * Devices that doesn't have a backlight
 */
static const struct fdt_match no_backlight_match[] = {
    {.compatible = "apple,d22" }, // iPhone X
    {.compatible = "apple,d221" },  // iPhone X
    {.compatible = "apple,j105a" }, // Apple TV 4K
    {.compatible = "apple,j42d" },  // Apple TV HD
    {.compatible = "apple,b238a" }, // HomePod
    {.compatible = "apple,t8012" }, // All T2
};

/*
 * Devices that doesn't have a framebuffer
 */
static const struct fdt_match no_framebuffer_match[] = {
    {.compatible = "apple,b238a" }, // HomePod
    // Then every non-Macbook Pro T2
    {.compatible = "apple,j137"},
    {.compatible = "apple,j140k"},
    {.compatible = "apple,j140a"},
    {.compatible = "apple,j160"},
    {.compatible = "apple,j174"},
    {.compatible = "apple,j185"},
    {.compatible = "apple,j185f"},
    {.compatible = "apple,j230k"},
};

int hlt_get_device_characteristics(void *fdt, uint16_t* chip_id, uint64_t* device_flags)
{
    const void *data;

    if (!hlt_fdt_match_compatible(fdt, 0, machine_match, &data))
        bail("unable to identify machine\n");

    uintptr_t cpid = (uintptr_t)data;
    printf("Current chip_id: %lx\n", cpid);
    *chip_id = (uint16_t)cpid;

    // Get device characteristics
    bool buttons = !hlt_fdt_match_compatible(fdt, 0, not_buttons_match, NULL);
    if (buttons)
        *device_flags |= DEVICE_FLAG_BUTTONS;

    bool has_fb = !hlt_fdt_match_compatible(fdt, 0, no_framebuffer_match, NULL);
    if (has_fb)
        *device_flags |= DEVICE_FLAG_FRAMEBUFFER;

    bool has_backlight = !hlt_fdt_match_compatible(fdt, 0, no_backlight_match, NULL);
    if (has_backlight)
        *device_flags |= DEVICE_FLAG_BACKLIGHT;

    if (cpid == 0x8015)
        *device_flags |= DEVICE_FLAG_NVME;

    return 0;
}
