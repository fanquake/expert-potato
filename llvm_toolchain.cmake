set(LLVM_TOOLCHAIN_PREFIX "${CMAKE_CURRENT_LIST_DIR}/llvm_toolchain" CACHE PATH "")

set(DEPENDS_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/bitcoin/depends/aarch64-unknown-linux-gnu/toolchain.cmake" CACHE FILEPATH "")

include("${DEPENDS_TOOLCHAIN_FILE}")

# Compile and link with the just-built toolchain.
set(CMAKE_C_COMPILER   "${LLVM_TOOLCHAIN_PREFIX}/bin/clang")
set(CMAKE_CXX_COMPILER "${LLVM_TOOLCHAIN_PREFIX}/bin/clang++")
set(CMAKE_AR           "${LLVM_TOOLCHAIN_PREFIX}/bin/llvm-ar")
set(CMAKE_RANLIB       "${LLVM_TOOLCHAIN_PREFIX}/bin/llvm-ranlib")
set(CMAKE_STRIP        "${LLVM_TOOLCHAIN_PREFIX}/bin/llvm-strip")
set(CMAKE_OBJCOPY      "${LLVM_TOOLCHAIN_PREFIX}/bin/llvm-objcopy")
set(CMAKE_OBJDUMP      "${LLVM_TOOLCHAIN_PREFIX}/bin/llvm-objdump")
set(CMAKE_LINKER_TYPE LLD)

# Locate the installed runtime archives. With LLVM_ENABLE_RUNTIMES they land
# in the per-target runtime directory (lib/<triple>/)
file(GLOB _llvm_libcxx
  "${LLVM_TOOLCHAIN_PREFIX}/lib/libc++.a"
  "${LLVM_TOOLCHAIN_PREFIX}/lib/*/libc++.a")
list(GET _llvm_libcxx 0 _llvm_libcxx)
get_filename_component(LLVM_RUNTIME_LIBDIR "${_llvm_libcxx}" DIRECTORY)

# Compile against the toolchain's libc++ headers; the C++ runtime itself is
# linked explicitly (and statically) below, hence -nostdlib++ at link time.
string(APPEND CMAKE_CXX_FLAGS_INIT " -stdlib=libc++")

# The single quotes around the pass list survive into the ninja rule
set(_opt_record_passes
  inline
  licm
  loop-unroll
  loop-vectorize
  regalloc
  slp-vectorizer
  stack-frame-layout
  wholeprogramdevirt
)
list(JOIN _opt_record_passes "|" _opt_record_passes)

# -Wl,--opt-remarks-with-hotness, needs PGO
string(JOIN " " CMAKE_EXE_LINKER_FLAGS
  -flto=full
  -fwhole-program-vtables
  -fstrict-vtable-pointers
  -nostdlib++
  --rtlib=compiler-rt
  -Wl,--icf=safe
  -Wl,-O2
  -Wl,--lto-O3
  -Wl,--lto-whole-program-visibility
  -Wl,--pack-dyn-relocs=relr
  -Wl,--save-temps
  -fsave-optimization-record
  "-foptimization-record-passes='${_opt_record_passes}'"
)

# LLVM libc in overlay mode: link libllvmlibc.a ahead of the system libc
# https://libc.llvm.org/overlay_mode.html
set(CMAKE_C_STANDARD_LIBRARIES "-L${LLVM_RUNTIME_LIBDIR} -lllvmlibc")

string(JOIN " " CMAKE_CXX_STANDARD_LIBRARIES
  ${CMAKE_C_STANDARD_LIBRARIES}
  -Wl,--start-group
  "${LLVM_RUNTIME_LIBDIR}/libc++.a"
  "${LLVM_RUNTIME_LIBDIR}/libc++abi.a"
  "${LLVM_RUNTIME_LIBDIR}/libunwind.a"
  -Wl,--end-group
)
