#!/usr/bin/env bash
set -euo pipefail

export CC=llvm_toolchain/bin/clang
export CXX=llvm_toolchain/bin/clang++
export AR=llvm_toolchain/llvm-ar
export NM=llvm_toolchain/bin/llvm-nm
export OBJCOPY=llvm_toolchain/bin/llvm-objcopy
export OBJDUMP=llvm_toolchain/bin/llvm-objdump
export RANLIB=llvm_toolchain/bin/llvm-ranlib
export STRIP=llvm_toolchain/bin/llvm-nm

# build_CC=llvm_toolchain/bin/clang
# build_CXX=llvm_toolchain/bin/clang++

CFLAGS=(
  -flto=full
  -mcpu=native
)

CXXFLAGS=(
  -fwhole-program-vtables
  -fstrict-vtable-pointers
  -fforce-emit-vtables
  -fassume-nothrow-exception-dtor
  )

LDFLAGS=(
  -fuse-ld=lld
  -fwhole-program-vtables
  -fstrict-vtable-pointers
)

make -C bitcoin/depends/ \
  NO_IPC=1 \
  NO_QT=1 \
  NO_USDT=1 \
  NO_WALLET=1 \
  NO_ZMQ=1 \
  CFLAGS="${CFLAGS[*]}" \
  CXXFLAGS="${CFLAGS[*]} ${CXXFLAGS[*]}" \
  LDFLAGS="${LDFLAGS[*]}"