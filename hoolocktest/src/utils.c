#include <libfdt.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdbool.h>
#include <spawn.h>
#include <sys/wait.h>

#include "utils.h"

int runCommand(const char *argv[]) {
    printf("runCommand: ");
    for (uint8_t i = 0; argv[i] != NULL; i++)
        printf("%s ", argv[i]);
    putchar('\n');
    fflush(stdout);
    pid_t pid;
    int ret = posix_spawn(&pid, argv[0], NULL, NULL, (char* const*)argv, environ);
    if (ret)
        bail("running command failed!\n");
    int status;
    if (waitpid(pid, &status, 0) < 0)
        bail("waitpid failed!");
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        bail("Child terminated by singal %d\n", WTERMSIG(status));
    }
    printf("unexpected child state change!\n");
    return -1;
}

bool file_exists(const char* path) {
    struct stat st;
    return !(stat(path, &st));
}
