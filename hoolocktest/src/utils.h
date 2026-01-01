#ifndef UTILS_H
#define UTILS_H

#include <stdbool.h>

#define BIT(x) (1 << x)

#define bail(...) do { printf("error: " __VA_ARGS__); printf(" ===== Ending HoolockTest ===== \n"); return -1; } while(0)
extern char **environ;
int runCommand(const char *argv[]);
bool file_exists(const char* path);

#define HLT_PATH(x) "/usr/lib/hoolocktest/" x

#endif
