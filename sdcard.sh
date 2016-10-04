#!/bin/bash
fex2bin=~/sunxi/sunxi-tools/fex2bin
imgfn=$1
if [ -z "$imgfn" ]; then
	echo "$0 imgfn.."
	exit
fi

rm $imgfn
echo "CREATE IMAGE"
sz=`du -sm rootfs.ext4 | awk '{print ($1)*2+50}'`
fallocate -l ${sz}M $imgfn

losetup -v -f ${imgfn}

#clear the first MB of sdimgfn
#dd if=/dev/zero of=${imgfn} bs=1M count=1
echo "CREATE IMAGE - CLEAR 1M"
dd if=/dev/zero of=/dev/loop0  bs=1M count=1

#write uboot to the imgfn
ls -l u-boot-sunxi-with-spl.bin
echo "CREATE IMAGE - UBOOT"
dd if=./u-boot-sunxi-with-spl.bin of=/dev/loop0 bs=1024 seek=8

#separate boot partition - 16MB with 1MB offset 
echo "CREATE IMAGE - REREAD"
losetup -d /dev/loop0
#sfdisk -R /dev/loop0
losetup -v -f ${imgfn}
echo "CREATE IMAGE - BOOTPART"
cat <<EOT | sfdisk --in-order -L -uM /dev/loop0
1,16,c
,,L
EOT

losetup -d /dev/loop0
#sfdisk -R /dev/loop0

#make the partitions
#p1
p1o=$(expr $(fdisk -lu ${imgfn} | grep ${imgfn}p1 | awk '{print $2}') \* 512)
p2o=$(expr $(fdisk -lu ${imgfn} | grep ${imgfn}p2 | awk '{print $2}') \* 512)
echo $p1o $p2o
losetup -v -f ${imgfn} -o $p1o
mkfs.vfat /dev/loop0
losetup -d /dev/loop0

losetup -v -f ${imgfn} -o $p2o
mkfs.ext4 /dev/loop0
losetup -d /dev/loop0

#now copy over the boor partition
losetup -v -f ${imgfn} -o $p1o
mkdir -p /mnt/pb
mount /dev/loop0 /mnt/pb
cp uImage /mnt/pb
rm script.bin
${fex2bin} sys_config.fex script.bin
cp script.bin /mnt/pb
rm boot.scr
mkimage -C none -A arm -T script -d boot.cmd boot.scr
cp boot.scr /mnt/pb
umount /mnt/pb
losetup -d /dev/loop0

#now copy over root
losetup -v -f ${imgfn} -o $p2o
#mount /dev/loop0 /mnt/pb
#tar -C /mnt/pb/ -xjpf rootfs.tar.bz2
#umount /mnt/pb
fsck.ext4 -y rootfs.ext4
dd if=rootfs.ext4 of=/dev/loop0
resize2fs /dev/loop0
mount /dev/loop0 /mnt/pb
cp rootfs.ext4 /mnt/pb
umount /mnt/pb
losetup -d /dev/loop0
