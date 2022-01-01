#!/bin/sh
#
# The purpose of the script is to install the bootloader on 
# a harddrive for Synology can be started from hard disk
#

#help screen
if  [ $# != 2 ]; then
echo "
standard use of script is:
    ./disk_setboot.sh  the script will install bootloader on hard disk, it will not
                       touch the partition tables and therefore please perserves data.
possible options are:
    /dev/sd?           device name for Synology bootloader disk.

    /*/boot.img        path to the bootloader that will be written to the disk.

example
    ./disk_setboot.sh /dev/sd? /volunm1/boot/boot612b.img
"
exit 1
fi

#check if the bootloader image exist
if  [ ! -f $2 ]; then
    echo "The bootloader image $2 does not exists."
    exit 1
fi

#check if the device exist
if [ ! -e $1 ]; then
    echo "$1 does not exist."
    exit 1
fi

if [ -e $1$(echo 4) ]; then
    part_data=$(parted --script $1$(echo 4) unit s p | grep "fat16")
    free_size=$(echo $part_data |cut -d's' -f3)
    if [ "$free_size" -lt 65536 ]; then
        echo "The device free size is too small for bootloader"
        exit 1
    fi
    dd if=$2 of=$1$(echo 4)
    sync
    sleep 1
    mount $1$(echo 4) /mnt
    if [ -x /mnt/grub ]; then
        LD_LIBRARY_PATH=/mnt
        export LD_LIBRARY_PATH
        /mnt/grub-install --force-lba --root-directory=/mnt $1$(echo 4)
    else
        echo "The boot img is not correct."
        exit 1
    fi
    umount /mnt
    echo "Update hard disk bootloader successful"
    exit 0
fi

#parted --script $1 unit s p free | grep "Free Space"  
#get the partition data
part_data=$(parted --script $1 unit s p free | grep "Free Space")
part_data=$(echo $part_data | sed -e 's/Free Space/;/g')
part_data=$(echo $part_data |cut -d';' -f2)

start_at=$(echo $part_data |cut -d's' -f1)
free_size=$(echo $part_data |cut -d's' -f3)
start_at=$((start_at+2048-start_at%2048))
end_at=$((start_at+65536))

if [ "$free_size" -lt 65536 ]; then
    echo "The device free size is too small for bootloader: {$((free_size*512))} bytes."
    exit 1
fi

parted $1 unit s mkpart primary fat16 $start_at$(echo s) $end_at$(echo s)
if [ $? != 0 ]; then
    echo "parted hard disk failure."
    exit 1
fi

parted $1 set 4 boot on
dd if=$2 of=$1$(echo 4)
sync
sleep 1
mount $1$(echo 4) /mnt
if [ -x /mnt/grub ]; then
    LD_LIBRARY_PATH=/mnt
    export LD_LIBRARY_PATH
    /mnt/grub-install --force-lba --root-directory=/mnt $1$(echo 4)
else
    echo "The boot img is not correct."
    exit 1
fi
umount /mnt
echo "Generate hard disk bootloader successful"
exit 0
