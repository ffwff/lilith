#!/bin/bash

for dir in ../userspace/applications/* ../userspace/libraries/*; do
    if [[ ! -e $(basename $dir) ]]; then
        echo $dir => $(basename $dir)
        ln -sf $dir $(basename $dir)
    fi
done
