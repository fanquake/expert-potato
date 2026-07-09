#!/usr/bin/env bash
set -euo pipefail

LLVM_SRC=../llvm-project
BUILD="llvm_build"
RUNTIMES_BUILD="runtimes_build"
PREFIX="$(pwd)/llvm_toolchain"

rm -rf "$BUILD" "$RUNTIMES_BUILD" "$PREFIX"

LTO_FLAGS=(
  -flto=full
)

RUNTIMES_FLAGS=(
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
  -DLLVM_ENABLE_PROJECTS='clang;lld' \
  -DLLVM_TARGETS_TO_BUILD=AArch64

cmake --build "$BUILD" --target install

cmake -S "$LLVM_SRC/runtimes" -B "$RUNTIMES_BUILD" -G Ninja \
  -DCMAKE_C_COMPILER="$PREFIX/bin/clang" \
  -DCMAKE_CXX_COMPILER="$PREFIX/bin/clang++" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_ASM_FLAGS="${RUNTIMES_FLAGS[*]}" \
  -DCMAKE_C_FLAGS="${LTO_FLAGS[*]} ${RUNTIMES_FLAGS[*]}" \
  -DCMAKE_CXX_FLAGS="${LTO_FLAGS[*]} ${RUNTIMES_FLAGS[*]} ${RUNTIMES_CXX_FLAGS[*]}" \
  -DCMAKE_AR="$PREFIX/bin/llvm-ar" \
  -DCMAKE_RANLIB="$PREFIX/bin/llvm-ranlib" \
  -DCMAKE_LINKER_TYPE=LLD \
  -DLLVM_ENABLE_RUNTIMES='libc;libcxx;libcxxabi;libunwind' \
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
  -DLIBCXX_HARDENING_MODE=none

cmake --build "$RUNTIMES_BUILD" --target install

rm -rf "$BUILD" "$RUNTIMES_BUILD"
