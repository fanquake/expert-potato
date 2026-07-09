#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

LLVM_SRC=$(pwd)/llvm-project
BUILD=llvm_build
PREFIX="$(pwd)/llvm_toolchain"

RUNTIMES_FLAGS=(
  -flto=full
  -mcpu=native
  -mbranch-protection=standard
  -fstack-protector-all
)
RUNTIMES_CXX_FLAGS=(
  -fwhole-program-vtables
  -fstrict-vtable-pointers
  -fforce-emit-vtables
)

cmake -S "$LLVM_SRC/llvm" -B "$BUILD" -G Ninja \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_C_FLAGS=-mcpu=native \
  -DCMAKE_CXX_FLAGS=-mcpu=native \
  -DCMAKE_AR="$(command -v llvm-ar)" \
  -DCMAKE_RANLIB="$(command -v llvm-ranlib)" \
  -DLLVM_CCACHE_BUILD=ON \
  -DLLVM_ENABLE_LLD=ON \
  -DLLVM_ENABLE_PROJECTS=clang \
  -DLLVM_ENABLE_RUNTIMES='libc;libcxx;libcxxabi;libunwind' \
  -DLLVM_TARGETS_TO_BUILD=AArch64 \
  -DRUNTIMES_CMAKE_C_FLAGS="${RUNTIMES_FLAGS[*]}" \
  -DRUNTIMES_CMAKE_CXX_FLAGS="${RUNTIMES_FLAGS[*]} ${RUNTIMES_CXX_FLAGS[*]}" \
  -DRUNTIMES_LLVM_USE_LINKER=lld \
  -DLIBCXX_ENABLE_SHARED=OFF \
  -DLIBCXX_ENABLE_STATIC=ON \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_ENABLE_STATIC=ON \
  -DLIBUNWIND_ENABLE_SHARED=OFF \
  -DLIBUNWIND_ENABLE_STATIC=ON \
  -DLIBCXX_HERMETIC_STATIC_LIBRARY=ON \
  -DLIBCXXABI_HERMETIC_STATIC_LIBRARY=ON \
  -DLIBCXX_CXX_ABI=libcxxabi \
  -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
  -DLIBCXX_HARDENING_MODE=none \
  -DLIBCXX_USE_COMPILER_RT=OFF

cmake --build "$BUILD"
cmake --install "$BUILD"
