#!/bin/sh
if [[ "$LILITH_ENV" -eq 1 ]]; then
  exit
fi
export LILITH_ENV=1
export PATH="$(pwd)/userspace/toolchain/tools/bin:$(pwd)/toolchain/crystal/.build:$PATH"
