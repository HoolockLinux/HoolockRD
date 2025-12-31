EXE = hoolocktest
ROOT != pwd
SRC = $(wildcard src/*.c)
OBJDIR = $(ROOT)/obj
OBJS = $(patsubst src/%,$(OBJDIR)/%,$(SRC:.c=.o)) $(PLATFORM_OBJS)
LDFLAGS ?= -fuse-ld=lld
CFLAGS ?= -target aarch64-linux-musl -Os
CFLAGS += -Wall -Wextra --sysroot="$(ROOT)/../work/rootfs"
CC := clang
LIBS = -lfdt

export OBJDIR CC CFLAGS

.PHONY: all

all: dirs $(OBJS) $(EXE)

dirs:
	@mkdir -p $(OBJDIR)

clean:
	@rm -rf $(EXE) obj

$(EXE): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) $(LIBS) -o $@

$(OBJDIR)/%.o: src/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

.PHONY: all dirs shellcode clean
