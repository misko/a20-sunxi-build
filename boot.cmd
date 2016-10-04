echo STARTING UBOOT MISKO
gpio clear 259
setenv bootm_boot_mode sec
if test ${reset_button} = "1" ; then setenv root /dev/mmcblk0p2; else setenv root /dev/mmcblk0p3; fi
setenv bootargs console=ttyS0,115200 root=${root} rootwait panic=10 ro
echo "Using root ${root}"
echo "Using bootargs ${bootargs}"
load mmc 0:1 0x43000000 script.bin || load mmc 0:1 0x43000000 boot/script.bin
load mmc 0:1 0x42000000 uImage || load mmc 0:1 0x42000000 boot/uImage
setenv machid 10bb
bootm 0x42000000
