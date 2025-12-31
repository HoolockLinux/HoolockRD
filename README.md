# HoolockLinux test ramdisk

Ramdisk to test the kernel in a semi-automated manner.

Some parts are based on postmarketOS ramdisk.

## Usage

Accept boot command line `hl_rd="word1 word2..."`. Currently valid `word`s are `test` and `shell`.
If not specified, defaults to `hl_rd="shell"`.

`test` causes /bin/hoolocktest to be ran
`shell` causes a shell to be spawned in a loop infinitely.

If `test` fails, a shell is spawned in a loop infinitely.

Otherwise, when the init script runs out of actions, the device is rebooted.
