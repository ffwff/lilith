#!/bin/sh

if [ ! -b /dev/loop0p1 ]; then
    sudo losetup -P /dev/loop0 drive.img || exit 1
fi
sudo umount /mnt
sudo mount /dev/loop0p1 /mnt || exit 1
i386-elf-lilith-gcc -g -o /tmp/main.bin userspace/programs/main.c
i386-elf-lilith-gcc -o /tmp/ls.bin userspace/programs/ls.c
sudo cp /tmp/main.bin /mnt
sudo cp /tmp/ls.bin /mnt
sudo cp ports/kilo/kilo /mnt/kilo.bin
sudo umount /mnt || exit 1