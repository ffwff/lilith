#!/bin/sh
if [[ "$LILITH_ENV" -ne 1 ]]; then
export LILITH_ENV=1
export PATH="$(pwd)/userspace/toolchain/tools/bin:$(pwd)/toolchain/crystal/.build:$PATH"
fi
