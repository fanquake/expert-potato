```
./build_llvm.sh
./build_depends.sh
./build_bitcoin.sh
```

What is in bitcoind, and why:
```bash
LDFLAGS="-Wl,-Map=bitcoind.map -Wl,--why-extract=whyextract.txt" ./build_bitcoin.sh

cat build/whyextract.txt
```

Did we get some llvm libc
```bash
llvm_toolchain/bin/llvm-nm -C build/bin/bitcoind | grep -i __llvm_libc | head
```

Check that all code is getting the same flags.
```bash
llvm_toolchain/bin/llvm-dis build/bin/bitcoind.0.5.precodegen.bc -o bc.ll
grep -oE '"target-(cpu|features)"="[^"]*"' bc.ll | sort | uniq -c

# Something like if you drop the flags from crc32c and shani
  194 "target-cpu"="neoverse-n1"
    1 "target-features"="+aes,+chk,+crc,+dotprod,+fp-armv8,+fullfp16,+gcs,+lse,+neon,+outline-atomics,+perfmon,+ras,+rcpc,+rdm,+sha2,+spe,+ssbs,+v8.1a,+v8.2a,+v8a,-fmv"
  193 "target-features"="+aes,+crc,+dotprod,+fp-armv8,+fullfp16,+lse,+neon,+outline-atomics,+perfmon,+ras,+rcpc,+rdm,+sha2,+spe,+ssbs,+v8.1a,+v8.2a,+v8a,-fmv"

# Where the outliers are probably:
unwind_phase2
unwind_phase2_forced
```
