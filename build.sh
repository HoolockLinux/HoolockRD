#!/bin/bash

set -e
set -o xtrace

SRCROOT="$(pwd)"
ROOTFS="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/aarch64/alpine-minirootfs-3.23.2-aarch64.tar.gz"
ARCH="$(arch)"

TARGET_CC="clang"
TARGET_CFLAGS="-target aarch64-linux-musl -fuse-ld=lld --sysroot=${SRCROOT}/work/rootfs"
TARGET_STRIP="llvm-strip"

if [ "$(id -u)" != "0" ]; then
	printf "Please run as root\n"
	exit 1
fi

rm -rf work
mkdir -pv work/rootfs
cd work
curl -sL "$ROOTFS" | tar -xzC rootfs

printf -- "--- SETUP CHROOT ---\n"

mount -vo bind /dev rootfs/dev
mount -vt sysfs sysfs rootfs/sys
mount -vt proc proc rootfs/proc
cp /etc/resolv.conf rootfs/etc
cat << ! > rootfs/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
!

if [ "$ARCH" != "aarch64" ]; then
	cp -v "$(command -v qemu-aarch64-static)" rootfs/usr/bin/emulator
	EMULATOR="/usr/bin/emulator"
	RUN_SH="/usr/bin/env PATH=/usr/bin:/usr/local/bin:/bin:/usr/sbin:/sbin $EMULATOR /bin/sh"
else
	EMULATOR=""
	RUN_SH="/usr/bin/env PATH=/usr/bin:/usr/local/bin:/bin:/usr/sbin:/sbin /bin/sh"
fi

printf -- "---- INSTALL BASE PACKAGES ----\n"


cat << ! | chroot rootfs $RUN_SH
apk update
apk upgrade
apk add unudhcpd busybox-extras evtest dtc-dev musl-dev util-linux gcc lm-sensors libgpiod
!

umount -l rootfs/dev
umount -l rootfs/sys
umount -l rootfs/proc

make -C ../external/coremark CC="${TARGET_CC}" XCFLAGS="${TARGET_CFLAGS}" coremark.exe
${TARGET_STRIP} ../external/coremark/coremark.exe

make -C ../hoolocktest
${TARGET_STRIP} ../hoolocktest/hoolocktest

mkdir initramfs initramfs-binpack
mkdir -p initramfs/{sbin,bin,usr/{bin,sbin},lib}
mkdir -p initramfs-binpack/{usr/lib/hoolocktest,bin,dev,proc,sys,run,tmp,usr/lib}
cp rootfs/lib/ld-musl-aarch64.so.1 initramfs/lib
cp rootfs/usr/lib/{libfdt.so.1,libsensors.so.5} initramfs-binpack/usr/lib
cp "rootfs/usr/lib/$(readlink rootfs/usr/lib/libgpiod.so.3)" initramfs-binpack/usr/lib/libgpiod.so.3
ln -s ld-musl-aarch64.so.1 initramfs/lib/libc.musl-aarch64.so.1
cp rootfs/bin/busybox initramfs/bin
cp rootfs/bin/busybox-extras initramfs-binpack/bin
cp rootfs/usr/bin/{evtest,unudhcpd,taskset,sensors,gpioset,gpioget,gpiodetect,gpiomon,gpionotify} initramfs-binpack/bin
install -m755 ../copybins/perf initramfs-binpack/bin
cp ../scripts/{init,init_functions.sh} initramfs
cp ../hoolocktest/scripts/* initramfs-binpack/usr/lib/hoolocktest
cp -a ../firmware initramfs/lib
install -m755 ../external/coremark/coremark.exe initramfs-binpack/bin/coremark
install -m755 ../hoolocktest/hoolocktest initramfs-binpack/bin
chmod 755 initramfs/init
chmod 644 initramfs/init_functions.sh

cd initramfs-binpack
fakeroot find . | cpio -ov --format=newc | lzma -zce6T1 > ../initramfs/extract.cpio.lzma
cd ..

cd initramfs
fakeroot find . | cpio -ov --format=newc > ../initramfs.cpio
gzip -c9 ../initramfs.cpio > ../../initramfs.gz
xz --check=crc32 -zce6T0 ../initramfs.cpio > ../../initramfs.xz

rm -f ../../initramfs.cpio

cd ..
#rm -rf work
