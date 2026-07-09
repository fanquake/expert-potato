#!/usr/bin/env bash
set -euo pipefail

TOOLCHAIN="$(pwd)/llvm_toolchain"

export CC="$TOOLCHAIN/bin/clang"
export CXX="$TOOLCHAIN/bin/clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export NM="$TOOLCHAIN/bin/llvm-nm"
export OBJCOPY="$TOOLCHAIN/bin/llvm-objcopy"
export OBJDUMP="$TOOLCHAIN/bin/llvm-objdump"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"

# build_CC=llvm_toolchain/bin/clang
# build_CXX=llvm_toolchain/bin/clang++

CFLAGS=(
  -O2
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
