# This file will be in /init_functions.sh inside the initramfs.
ROOT_PARTITION_UNLOCKED=0

# NOTE!!! The file is sourced again in init_2nd.sh, avoid
# clobbering variables by not setting them if they have
# a value already!
CONFIGFS="/config/usb_gadget"
CONFIGFS_ACM_FUNCTION="acm.usb0"
HOST_IP="172.16.42.1"
deviceinfo_getty="/dev/ttySAC0;115200"
deviceinfo_name="HoolockLinux USB Device"
deviceinfo_codename="idevice"

# Redirect stdout and stderr to logfile
setup_log() {
	local console
	console="$(cat /sys/devices/virtual/tty/console/active)"

	deviceinfo_getty="/dev/ttySAC0;115200"
	if [ -f "/dev/ttySAC6" ]; then
		deviceinfo_getty="/dev/ttySAC6;115200";
	fi

	# Stash fd1/2 so we can restore them before switch_root, but only if the
	# console is not null
	if [ -n "$console" ] ; then
		# The kernel logs go to the console, and we log to the kernel. Avoid printing everything
		# twice.
		console="/dev/null"
		exec 3>&1 4>&2
	else
		# Setting console=null is a trick used on quite a few pmOS devices. However it is generally a really
		# bad idea since it makes it impossible to debug kernel panics, and it makes our job logging in the
		# initramfs a lot harder. We ban this in pmaports but some (usually android) bootloaders like to add it
		# anyway. We ought to have some special handling here to use /dev/zero for stdin instead
		# to avoid weird bugs in daemons that read from stdin (e.g. syslog)
		# See related: https://gitlab.postmarketos.org/postmarketOS/pmaports/-/issues/2989
		console="/dev/$(echo "$deviceinfo_getty" | cut -d';' -f1)"
		if ! [ -e "$console" ]; then
			console="/dev/null"
		fi
	fi

	# Disable kmsg ratelimiting for userspace (it gets re-enabled again before switch_root)
	echo on > /proc/sys/kernel/printk_devkmsg

	# Spawn syslogd to log to the kernel
	syslogd -K

	local pmsg="/dev/pmsg0"

	if ! [ -e "$pmsg" ]; then
		pmsg="/dev/null"
	fi

	# Redirect to a subshell which outputs to the logfile as well
	# as to the kernel ringbuffer and pstore (if available).
	# Process substitution is technically non-POSIX, but is supported by busybox
	# shellcheck disable=SC3001
	exec > >(tee /HL_init.log "$pmsg" "$console" | logger -t "$LOG_PREFIX" -p user.info) 2>&1
}

mount_proc_sys_dev() {
	# mdev
	mount -t proc -o nodev,noexec,nosuid proc /proc || echo "Couldn't mount /proc"
	mount -t sysfs -o nodev,noexec,nosuid sysfs /sys || echo "Couldn't mount /sys"
	mount -t devtmpfs -o mode=0755,nosuid dev /dev || echo "Couldn't mount /dev"
	mount -t tmpfs -o nosuid,nodev,mode=0755 run /run || echo "Couldn't mount /run"

	mkdir /config
	mount -t configfs -o nodev,noexec,nosuid configfs /config

	# /dev/pts (needed for telnet)
	mkdir -p /dev/pts
	mount -t devpts devpts /dev/pts

	# This is required for process substitution to work (as used in setup_log())
	ln -s /proc/self/fd /dev/fd
}

setup_mdev() {
	# Start mdev daemon
	mdev -d
}

get_usb_udc() {
	_udc_dev=$(ls /sys/class/udc | head -1)
	echo "$_udc_dev"
}

get_uptime_seconds() {
	# Get the current system uptime in seconds - ignore the two decimal places.
	awk -F '.' '{print $1}' /proc/uptime
}

run_hooks() {
	scriptsdir="$1"

	if [ -z "$(ls -A "$scriptsdir" 2>/dev/null)" ]; then
		return
	fi

	for hook in "$scriptsdir"/*.sh; do
		echo "Running initramfs hook: $hook"
		sh "$hook"
	done
}

set_usb_udc() {
	local _udc_dev="${deviceinfo_usb_network_udc:-}"
	if [ -z "$_udc_dev" ]; then
		# shellcheck disable=SC2012
		_udc_dev=$(ls /sys/class/udc | head -1)
	fi

	echo "$_udc_dev"
}

setup_usb_configfs_udc() {
	# Check if there's an USB Device Controller
	local _udc_dev
	_udc_dev="$(get_usb_udc)"

	# Remove any existing UDC to avoid "write error: Resource busy" when setting UDC again
	if [ "$(wc -w <$CONFIGFS/g1/UDC)" -gt 0 ]; then
		echo "" > "$CONFIGFS"/g1/UDC || echo "  Couldn't write to clear UDC"
	fi
	# Link the gadget instance to an USB Device Controller. This activates the gadget.
	# See also: https://gitlab.postmarketos.org/postmarketOS/pmbootstrap/issues/338
	echo "$_udc_dev" > "$CONFIGFS"/g1/UDC || echo "  Couldn't write new UDC"
}

# $1: if set, skip writing to the UDC
setup_usb_network_configfs() {
	# See: https://www.kernel.org/doc/Documentation/usb/gadget_configfs.txt
	local skip_udc="$1"

	if ! [ -e "$CONFIGFS" ]; then
		echo "$CONFIGFS does not exist, skipping configfs usb gadget"
		return
	fi

	if [ -z "$(get_usb_udc)" ]; then
		echo "  No UDC found, skipping usb gadget"
		return
	fi

	# Default values for USB-related deviceinfo variables
	usb_idVendor="0x05ac"   # default: Apple, Inc.
	usb_idProduct="0x4142"
	usb_serialnumber="$(cat /proc/device-tree/serial-number)"
	usb_network_function="ncm.usb0"
	usb_network_function_fallback="rndis.usb0"

	if [ "$usb_serialnumber" = "" ]; then
		usb_serialnumber="unknown";
	fi

	echo "  Setting up USB gadget through configfs"
	# Create an usb gadet configuration
	mkdir $CONFIGFS/g1 || echo "  Couldn't create $CONFIGFS/g1"
	echo "$usb_idVendor"  > "$CONFIGFS/g1/idVendor"
	echo "$usb_idProduct" > "$CONFIGFS/g1/idProduct"

	# Create english (0x409) strings
	mkdir $CONFIGFS/g1/strings/0x409 || echo "  Couldn't create $CONFIGFS/g1/strings/0x409"

	# shellcheck disable=SC2154
	echo "$deviceinfo_manufacturer" > "$CONFIGFS/g1/strings/0x409/manufacturer"
	echo "$usb_serialnumber"        > "$CONFIGFS/g1/strings/0x409/serialnumber"
	# shellcheck disable=SC2154
	echo "$deviceinfo_name"         > "$CONFIGFS/g1/strings/0x409/product"

	# Create network function.
	if ! mkdir $CONFIGFS/g1/functions/"$usb_network_function"; then
		# Try the fallback function next
		if mkdir $CONFIGFS/g1/functions/"$usb_network_function_fallback"; then
			usb_network_function="$usb_network_function_fallback"
		fi
	fi

	# Create configuration instance for the gadget
	mkdir $CONFIGFS/g1/configs/c.1 \
		|| echo "  Couldn't create $CONFIGFS/g1/configs/c.1"
	mkdir $CONFIGFS/g1/configs/c.1/strings/0x409 \
		|| echo "  Couldn't create $CONFIGFS/g1/configs/c.1/strings/0x409"
	echo "USB network" > $CONFIGFS/g1/configs/c.1/strings/0x409/configuration \
		|| echo "  Couldn't write configration name"

	# Link the network instance to the configuration
	ln -s $CONFIGFS/g1/functions/"$usb_network_function" $CONFIGFS/g1/configs/c.1 \
		|| echo "  Couldn't symlink $usb_network_function"

	# If an argument was supplied then skip writing to the UDC (only used for mass storage
	# log recovery)
	if [ -z "$skip_udc" ]; then
		setup_usb_configfs_udc
	fi
}

setup_usb_network() {
	# Only run once
	_marker="/tmp/_setup_usb_network"
	[ -e "$_marker" ] && return
	touch "$_marker"
	echo "Setup usb network"
	# Run all usb network setup functions (add more below!)
	setup_usb_network_configfs
}

start_unudhcpd() {
	# Only run once
	[ "$(pidof unudhcpd)" ] && return

	# Skip if disabled
	# shellcheck disable=SC2154
	if [ "$deviceinfo_disable_dhcpd" = "true" ]; then
		return
	fi

	local client_ip="${unudhcpd_client_ip:-172.16.42.2}"
	echo "Starting unudhcpd with server ip $HOST_IP, client ip: $client_ip"

	# Get usb interface
	usb_network_function="${deviceinfo_usb_network_function:-ncm.usb0}"
	usb_network_function_fallback="rndis.usb0"
	if [ -n "$(cat $CONFIGFS/g1/UDC)" ]; then
		INTERFACE="$(
			cat "$CONFIGFS/g1/functions/$usb_network_function/ifname" 2>/dev/null ||
			cat "$CONFIGFS/g1/functions/$usb_network_function_fallback/ifname" 2>/dev/null ||
			echo ''
		)"
	else
		INTERFACE=""
	fi
	if [ -n "$INTERFACE" ]; then
		ifconfig "$INTERFACE" "$HOST_IP"
	elif ifconfig rndis0 "$HOST_IP" 2>/dev/null; then
		INTERFACE=rndis0
	elif ifconfig usb0 "$HOST_IP" 2>/dev/null; then
		INTERFACE=usb0
	elif ifconfig eth0 "$HOST_IP" 2>/dev/null; then
		INTERFACE=eth0
	fi

	if [ -z "$INTERFACE" ]; then
		echo "  Could not find an interface to run a dhcp server on"
		echo "  Interfaces:"
		ip link
		return
	fi

	echo "  Using interface $INTERFACE"
	echo "  Starting the DHCP daemon"
	(
		unudhcpd -i "$INTERFACE" -s "$HOST_IP" -c "$client_ip"
	) &
}

setup_usb_acm_configfs() {
	active_udc="$(cat $CONFIGFS/g1/UDC)"

	if ! [ -e "$CONFIGFS" ]; then
		echo "  $CONFIGFS does not exist, can't set up serial gadget"
		return 1
	fi

	# unset UDC
	echo "" > $CONFIGFS/g1/UDC

	# Create acm function
	mkdir "$CONFIGFS/g1/functions/$CONFIGFS_ACM_FUNCTION" \
		|| echo "  Couldn't create $CONFIGFS/g1/functions/$CONFIGFS_ACM_FUNCTION"

	# Link the acm function to the configuration
	ln -s "$CONFIGFS/g1/functions/$CONFIGFS_ACM_FUNCTION" "$CONFIGFS/g1/configs/c.1" \
		|| echo "  Couldn't symlink $CONFIGFS_ACM_FUNCTION"

	return 0
}

# Spawn a subshell to restart the getty if it exits
# $1: tty
run_getty() {
	{
		# Due to how the Linux host ACM driver works, we need to wait
		# for data to be sent from the host before spawning the getty.
		# Otherwise our README message will be echo'd back all garbled.
		# On Linux in particular, there is a hack we can use: by writing
		# something to the port, it will be echo'd back at the moment the
		# port on the host side is opened, so user input won't even be
		# needed in most cases. For more info see the blog posts at:
		# https://michael.stapelberg.ch/posts/2021-04-27-linux-usb-virtual-serial-cdc-acm/
		# https://connolly.tech/posts/2024_04_15-broken-connections/
		if [ "$1" = "ttyGS0" ]; then
			echo " " > /dev/ttyGS0
			# shellcheck disable=SC3061
			read -r < /dev/ttyGS0
		fi
		while /sbin/getty -n -l /sbin/pmos_getty "$1" 115200 vt100; do
			sleep 0.2
		done
	} &
}

debug_shell() {
	echo "Entering debug shell"
	# if we have a UDC it's already been configured for USB networking
	local have_udc
	have_udc="$(cat $CONFIGFS/g1/UDC)"

	if [ -n "$have_udc" ]; then
		setup_usb_acm_configfs
	fi

	# mount pstore, if possible
	if [ -d /sys/fs/pstore ]; then
		mount -t pstore pstore /sys/fs/pstore || true
	fi

	mount -t debugfs none /sys/kernel/debug || true
	# make a symlink like Android recoveries do
	ln -s /sys/kernel/debug /d

	cat <<-EOF > /README

	HoolockLinux test ramdisk shell

	Logs available in /HL_init.log

	EOF

	cat <<-EOF > /sbin/pmos_getty
	#!/bin/sh
	cat /README
	/bin/sh -l
	EOF
	chmod +x /sbin/pmos_getty

	# Get the console (ttyX) associated with /dev/console
	local active_console
	active_console="$(cat /sys/devices/virtual/tty/tty0/active)"
	# Get a list of all active TTYs include serial ports
	local serial_ports
	serial_ports="$(cat /sys/devices/virtual/tty/console/active)"
	# Get the getty device too (might not be active)
	local getty
	getty="/dev/ttySAC0"
	if [ -f "/dev/ttySAC6" ]; then
		getty="/dev/ttySAC6";
	fi

	# Run getty's on the consoles
	for tty in $serial_ports; do
		# Some ports we handle explicitly below to make sure we don't
		# accidentally spawn two getty's on them
		if echo "tty0 tty1 ttyGS0 $getty" | grep -q "$tty" ; then
			continue
		fi
		run_getty "$tty"
	done

	if [ -n "$getty" ]; then
		run_getty "$getty"
	fi

	# Rewrite tty to tty1 if tty0 is active
	if [ "$active_console" = "tty0" ]; then
		active_console="tty1"
	fi

	run_getty "$active_console"

	# And on the usb acm port (if it exists)
	if [ -e /dev/ttyGS0 ]; then
		run_getty ttyGS0
	fi

	# To avoid racing with the host PC opening the ACM port, we spawn
	# the getty first. See the comment in run_getty for more details.
	setup_usb_configfs_udc

	# Spawn telnetd for those who prefer it. ACM gadget mode is not
	# supported on some old kernels so this exists as a fallback.
	telnetd -b "${HOST_IP}:23" -l /sbin/pmos_getty &
}
