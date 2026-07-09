```
./build_llvm.sh
./build_depends.sh
cmake -S bitcoin -G Ninja -B build --toolchain /root/llvm_toolchain.cmake ...
```