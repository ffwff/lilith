#!/bin/sh

if [ ! -b /dev/loop0p1 ]; then
    sudo losetup -P /dev/loop0 drive.img
fi
sudo mount /dev/loop0p1 /mnt
i386-elf-lilith-gcc -o /tmp/main.bin userspace/programs/main.c
i386-elf-lilith-gcc -o /tmp/ls.bin userspace/programs/ls.c
sudo cp /tmp/main.bin /mnt
sudo cp /tmp/ls.bin /mnt
sudo umount /mnt