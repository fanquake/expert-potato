#!/usr/bin/env bash
set -euo pipefail

LLVM_SRC=../llvm-project
BUILD="llvm_build"
RUNTIMES_BUILD="runtimes_build"
PREFIX="$(pwd)/llvm_toolchain"

rm -rf "$BUILD" "$RUNTIMES_BUILD" "$PREFIX"

# Drop qsort/qsort_r from llvm-libc: in overlay mode with -static-pie
# we collide with glibc.
cat > "$LLVM_SRC/libc/config/linux/aarch64/exclude.txt" <<'EOF'
list(APPEND TARGET_LLVMLIBC_REMOVED_ENTRYPOINTS
  libc.src.stdlib.qsort
  libc.src.stdlib.qsort_r
)
EOF

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
  -DLLVM_ENABLE_PROJECTS='bolt;clang;lld' \
  -DLLVM_TARGETS_TO_BUILD=AArch64

cmake --build "$BUILD" --target install

TRIPLE=aarch64-unknown-linux-gnu

cmake -S "$LLVM_SRC/runtimes" -B "$RUNTIMES_BUILD" -G Ninja \
  -DCMAKE_C_COMPILER="$PREFIX/bin/clang" \
  -DCMAKE_CXX_COMPILER="$PREFIX/bin/clang++" \
  -DCMAKE_C_COMPILER_TARGET="$TRIPLE" \
  -DCMAKE_CXX_COMPILER_TARGET="$TRIPLE" \
  -DCMAKE_ASM_COMPILER_TARGET="$TRIPLE" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_ASM_FLAGS="${RUNTIMES_FLAGS[*]}" \
  -DCMAKE_C_FLAGS="${LTO_FLAGS[*]} ${RUNTIMES_FLAGS[*]}" \
  -DCMAKE_CXX_FLAGS="${LTO_FLAGS[*]} ${RUNTIMES_FLAGS[*]} ${RUNTIMES_CXX_FLAGS[*]}" \
  -DCMAKE_AR="$PREFIX/bin/llvm-ar" \
  -DCMAKE_RANLIB="$PREFIX/bin/llvm-ranlib" \
  -DCMAKE_LINKER_TYPE=LLD \
  -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
  -DLLVM_ENABLE_RUNTIMES='libc;libcxx;libcxxabi;libunwind;compiler-rt' \
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
  -DLIBCXX_USE_COMPILER_RT=ON \
  -DLIBCXXABI_USE_COMPILER_RT=ON \
  -DLIBUNWIND_USE_COMPILER_RT=ON \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
  -DCOMPILER_RT_BUILD_BUILTINS=ON \
  -DCOMPILER_RT_BUILD_CRT=OFF \
  -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
  -DCOMPILER_RT_BUILD_XRAY=OFF \
  -DCOMPILER_RT_BUILD_PROFILE=OFF \
  -DCOMPILER_RT_BUILD_MEMPROF=OFF \
  -DCOMPILER_RT_BUILD_ORC=OFF \
  -DCOMPILER_RT_BUILD_GWP_ASAN=OFF \
  -DCOMPILER_RT_BUILD_LIBFUZZER=OFF

cmake --build "$RUNTIMES_BUILD" --target install

rm -rf "$BUILD" "$RUNTIMES_BUILD"
