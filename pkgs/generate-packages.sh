#!/bin/sh

for dir in ../userspace/applications/* ../userspace/libraries/*; do
    if [[ ! -e $dir ]]; then
    	ln -sf $dir $(basename $dir)
    fi
done