fatload mmc 0 0x43000000 script.bin
fatload mmc 0 0x48000000 uImage
setenv bootargs console=tty0 root=/dev/mmcblk0p2 rootwait panic=10
bootm 0x48000000
