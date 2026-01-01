#ifndef DEVICE_H
#define DEVICE_H

#include "utils.h"
#include <stdint.h>

#define DEVICE_FLAG_BUTTONS         BIT(0) // iPhone, iPad, iPod touch
#define DEVICE_FLAG_BACKLIGHT           BIT(1) // Has backlight (OLED != backlight)
#define DEVICE_FLAG_FRAMEBUFFER         BIT(2) // Device has a screen
#define DEVICE_FLAG_NVME                BIT(3) // NVME Internal storage is supported

int hlt_get_device_characteristics(void *fdt, uint16_t* chip_id, uint64_t* device_flags);

#endif
