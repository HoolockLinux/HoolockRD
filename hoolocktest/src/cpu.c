#include <libfdt.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>
#include <errno.h>
#include <spawn.h>

#include "utils.h"
#include "cpu.h"

int test_smp(uint16_t cpid)
{
    long cpus = sysconf(_SC_NPROCESSORS_ONLN);
    if (cpus < 1)
        bail("could not online cpus: %ld\n", cpus);

    uint16_t expected_procs = 2;
    if (cpid == 0x7001 || cpid == 0x8011)
        expected_procs = 3;
    else if (cpid == 0x8015)
        expected_procs = 6;

    if (expected_procs != cpus)
        bail("unexpected number of cpus expected %hd got %ld\n", expected_procs, cpus);
    return 0;
}

int test_cpufreq(uint16_t cpid)
{
    char buf[8];
    snprintf(buf, 8, "0x%hx", cpid);

    return runCommand((const char*[]){ HLT_PATH("test_cpufreq"), buf, NULL});
}

int test_cpmu(uint16_t cpid)
{
    char buf[8];
    snprintf(buf, 8, "0x%hx", cpid);

    int ret = runCommand((const char*[]){ HLT_PATH("test_cpmu"), buf, NULL});
    if (ret)
        bail("cpmu test script failed!\n");

    struct stat st;
    if (stat("./perf.data", &st))
        bail("Couldn't stat perf.data file: %d\n", errno);

    if (st.st_size < 524288)
        bail("perf.data file too small\n");

    return 0;
}
