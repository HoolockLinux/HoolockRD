EXE = hoolocktest
ROOT != pwd
SRC = $(wildcard src/*.c)
OBJDIR = $(ROOT)/obj
OBJS = $(patsubst src/%,$(OBJDIR)/%,$(SRC:.c=.o)) $(PLATFORM_OBJS)
LDFLAGS ?=
LDFLAGS += -L$(ROOT)/../work/rootfs/usr/lib -fuse-ld=lld
CFLAGS ?= -target aarch64-linux-musl -nostdlibinc -Os -I$(ROOT)/../work/rootfs/usr/include
CFLAGS += -Wall -Wextra
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
	$(CC) $(CFLAGS) $(INCLDIRS) -c -o $@ $<

.PHONY: all dirs shellcode clean
