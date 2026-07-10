#!/usr/bin/env bash
set -euo pipefail

rm -rf build

cmake -S bitcoin -B build -G Ninja \
  --toolchain "$(pwd)/llvm_toolchain.cmake" \
  -DENABLE_EXTERNAL_SIGNER=OFF \
  -DREDUCE_EXPORTS=ON \
  -DAPPEND_LDFLAGS="${LDFLAGS:-} -static-pie"

cmake --build build --target bitcoind
