#!/usr/bin/env bash
set -euo pipefail

PROFDATA="$(pwd)/bitcoind.profdata"

cmake -S bitcoin -B build -G Ninja \
  --toolchain "$(pwd)/llvm_toolchain.cmake" \
  -DENABLE_EXTERNAL_SIGNER=OFF \
  -DREDUCE_EXPORTS=ON \
  -DAPPEND_LDFLAGS="-static-pie"

cmake --build build
