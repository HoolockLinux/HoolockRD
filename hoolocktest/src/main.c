#include <time.h>
#include <libfdt.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>
#include <time.h>

#include "fdt.h"
#include "utils.h"
#include "device.h"
#include "cpu.h"

int main(void)
{
    void *fdt;
    uint64_t device_flags = 0;
    uint16_t chip_id;
    int ret;

    printf(" ===== Starting HoolockTest ===== \n");

    if (hlt_load_fdt(&fdt))
        bail("load fdt failed!\n");

    if (hlt_get_device_characteristics(fdt, &chip_id, &device_flags))
        bail("failed getting device info\n");

    if (test_smp(chip_id))
        bail("smp test failed\n");
    printf("SMP test OK\n");

    if (test_cpufreq(chip_id))
        bail("cpufreq test failed\n");
    printf("cpufreq test OK\n");

    if (device_flags & DEVICE_FLAG_BACKLIGHT) {
        ret = runCommand((const char*[]){HLT_PATH("test_backlight"), NULL});
        if (ret)
            bail("backlight test failed\n");
        printf("Backlight test OK\n");
    }

    if (device_flags & DEVICE_FLAG_NVME) {
        ret = runCommand((const char*[]){HLT_PATH("test_nvme"), NULL});
        if (ret)
            bail("nvme test failed\n");
        printf("NVME test OK\n");
    }

    if (test_cpmu(chip_id))
        bail("cpmu test failed\n");
    printf("CPMU test OK\n");

    if (device_flags & DEVICE_FLAG_FRAMEBUFFER) {
        if (!file_exists("/dev/fb0"))
            bail("framebuffer does not exist\n");
        printf("Framebuffer existence test OK\n");
    }

    ret = runCommand((const char*[]){HLT_PATH("test_usb"), NULL});
    if (ret)
        bail("usb test failed\n");
    printf("USB existence test OK\n");

    if (!file_exists("/sys/class/watchdog/watchdog0"))
        bail("watchdog file does not exist");
    printf("Watchdog existence test OK\n");

    // require at least 1 gpiochip
    if (!file_exists("/sys/bus/gpio/devices/gpiochip0"))
        bail("gpiochip0 file does not exist");
    printf("gpiochip existence test OK\n");

    if ((device_flags & DEVICE_FLAG_BUTTONS)) {
        if (!file_exists("/dev/input/event0"))
            bail("input event file does not exist");

        printf("Input event existence test OK\n");
    }

    if ((chip_id == 0x8015 || chip_id == 0x8012)) {
        if (!file_exists("/sys/bus/platform/drivers/macsmc"))
            bail("macsmc event file does not exist");

        printf("macsmc existence test OK\n");
    }
    time_t t = time(NULL);
    if (t < 1009814400) // 2002-01-01
        bail("rtc test failed (earlier than 2002)\n");

    if (chip_id == 0x8015) {
        ret = runCommand((const char*[]){HLT_PATH("test_battery"), NULL});
        if (ret)
            bail("battery test failed\n");
        printf("battery test OK\n");
    }

    printf("HoolockLinux Test -- SUCCESS\n");
    printf(" ===== Ending HoolockTest ===== \n"); 

    return 0;
}
