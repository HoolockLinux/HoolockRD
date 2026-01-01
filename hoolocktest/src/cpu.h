#ifndef CPU_H
#define CPU_H

#include <stdint.h>

int test_cpufreq(uint16_t cpid);
int test_cpmu(uint16_t cpid);
int test_smp(uint16_t cpid);

#endif
