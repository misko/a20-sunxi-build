#!/bin/bash
#
# This is script could be used to transfer filesystem from MMC to eMMC.
#
# Copyright (C) 2016 Stefan Mavrodiev, OLIMEX LTD.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT 
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.

# Release 0.0.1 / 6 APR 2016
#


# Set default values
MMC_DEVICE=${MMC:="/dev/mmcblk0"}
EMMC_DEVICE=${EMMC:="/dev/mmcblk1"}

function check_mounted() {
    [ -z $1 ] && return

    [ $MMC_DEVICE"p2" = "$1" ] && echo "/" && return
    
    line=$(df | grep "$1")
    [ -z "$line" ] && return
    
    echo $(echo $line | awk '{ print $6 }')
}

function print_with_color() {
    echo -e "\e[33m"$1"\e[0m"
}


# Check for root
print_with_color "Checking permissions..."
[ $(id -u) -ne 0 ] && echo "This script must be run as root!" && exit 1



# Check if MMC and eMMC are present
print_with_color "Checking MMC device..."
[ ! -e $MMC_DEVICE ] && 
    echo "MMC device \"$MMC_DEVICE\" is missing!" &&
    exit 1

print_with_color "Checking eMMC device..."
[ ! -e $EMMC_DEVICE ] &&
    echo "eMMC device \"$EMMC_DEVICE\" is missing!" &&
    exit 1

    
    
# Capture output from fdisk
fdisk_output=$(fdisk $MMC_DEVICE -l | grep -v 'does not end on cylinder boundary')




# Read format table of the MMC
print_with_color "Reading partition table.."
partitions_end=$(echo "$fdisk_output" | wc -l)
[ -z $partitions_end ] && echo "Failed to get MMC partition table!" && exit 1



# Parse fdisk output
partitions_line=$(echo "$fdisk_output" | \
    grep "Device" -n | \
    awk -F':' '{ print $1 }')

[ -z $partitions_line ] && echo "Failed to get MMC partition table!" && exit 1




# Make sure partition table on eMMC is not mounted and erased
print_with_color "Erasing eMMC partition table..."
for p in $(ls $EMMC_DEVICE*); do
    umount $p > /dev/null 2>&1
done
dd if="/dev/zero" of=$EMMC_DEVICE bs=1M count=20 > /dev/null 2>&1



# Copy bootloader
print_with_color "Copying bootloader..."
dd if=$MMC_DEVICE of=$EMMC_DEVICE skip=16 seek=16 count=2032 > /dev/null 2>&1


# The first partition in on the next line
partitions_line=$((partitions_line+1))



# Read the first partition parameters
partition=$(echo "$fdisk_output" | head -n $partitions_line | tail -n 1)

p=1
while [ $partitions_line -le $partitions_end ]; do
    echo "P LINE" $partitions_line $partition

    # Check target fs
    #echo fsck -NT $MMC_DEVICE"p"$p
    #fsck -NT $MMC_DEVICE"p"$p
    fs=$(eval $(blkid $MMC_DEVICE"p"$p | awk ' { print $3 } '); echo $TYPE)
    echo $fs "FS TYPE"
    #fs=$(fsck -NT $MMC_DEVICE"p"$p | awk '{ print $5}' | \
    #    awk -F'.' '{ print $2 }')
    [ -z $fs ] && echo "Unknown target filesystem!" && exit 1
    
    
    # First read partiton start/end sector
    start=$(echo $partition | awk '{print $2}')
    end=$(echo $partition | awk '{print $3}')
    
    [ $partitions_line -eq $partitions_end ] && end=""
    
    print_with_color "Creating partition: $p"
    if [ "$fs" == "vfat" ]; then
    
        if [ $p -eq 1 ]; then
            fdisk $EMMC_DEVICE > /dev/null 2>&1 << __EOF__
n
p
$p
$start
$end
t
b
w
__EOF__

        else
            fdisk $EMMC_DEVICE > /dev/null 2>&1 << __EOF__
n
p
$p
$start
$end
t
$p
b
w
__EOF__
        fi

    else
        fdisk $EMMC_DEVICE > /dev/null 2>&1 << __EOF__
n
p
$p
$start
$end
w
__EOF__
    fi



    # Make file system
    print_with_color "Formating to $fs..."
    echo mkfs.$fs $EMMC_DEVICE"p"$p 
    mkfs.$fs $EMMC_DEVICE"p"$p > /dev/null 2>&1
    
    # Create mount points
    mkdir ./mmc > /dev/null 2>&1
    mkdir ./emmc > /dev/null 2>&1
    
    mount_point=$(check_mounted $MMC_DEVICE"p"$p)
   
    echo ${mount_point} 
     if [ -z "$mount_point" ]; then
        mount_point="./mmc"
        mount $MMC_DEVICE"p"$p $mount_point
     fi
    
    mount $EMMC_DEVICE"p"$p ./emmc
    
    # Copy files
    print_with_color "Copying files..."
    echo cp -rvfp $mount_point/* ./emmc
    
    print_with_color "Syncing..."
    echo sync
    
    #echo umount $EMMC_DEVICE"p"$p #> /dev/null 2>&1
    #echo umount $MMC_DEVICE"p"$p #> /dev/null 2>&1
    if [ "$mount_point" = "./mmc" ] ; then
      umount ./mmc
    fi
    umount ./emmc
    
    rm -rf ./mmc
    rm -rf ./emmc
    
    # Read next partition on the table
    partitions_line=$((partitions_line+1))
    p=$((p+1))
    partition=$(echo "$fdisk_output" | head -n $partitions_line | tail -n 1)

done

print_with_color "Finished!"
exit 0
