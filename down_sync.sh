#!/bin/bash
rsync -azP misko@159.203.252.147:~/uImage  ./
rsync -azP misko@159.203.252.147:~/rootfs.ext4  ./
#fsck.ext4 -y rootfs.ext4 
