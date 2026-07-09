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
```
llvm-nm -C build/bin/bitcoind | grep -i __llvm_libc | head
```

`-static-pie` currently broken with at least duplicated `qsort`:
```
LDFLAGS="-Wl,-z,muldefs -static-pie" ./build_bitcoin.sh
```
