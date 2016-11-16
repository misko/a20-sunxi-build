#!/bin/bash
ip=159.203.252.147
ip=192.168.2.120
rsync -aP misko@${ip}:/dev/shm//uImage  ./
rsync -aP misko@${ip}:/dev/shm//rootfs.ext4  ./
#fsck.ext4 -y rootfs.ext4 
