```
./build_llvm.sh
./build_depends.sh
cmake -S bitcoin -G Ninja -B build --toolchain "$PWD/llvm_toolchain.cmake" ...
```