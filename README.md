# Core x LLVM

```
./build_llvm.sh
./build_depends.sh
./build_bitcoin.sh
./apply_bolt.sh
```

## llvm-project submodule

Currently tracking `release/23.x` (minimum for -static-pie in bolt).
Update tracked branch with: `git submodule update --remote --depth 1`.

## LLVM libc

Did we get some llvm libc
```bash
llvm_toolchain/bin/llvm-nm -C build/bin/bitcoind | grep -i __llvm_libc | head
```

## Uniform compilation flags

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

## Binary contents

What is in bitcoind, and why:
```bash
LDFLAGS="-Wl,-Map=bitcoind.map -Wl,--why-extract=whyextract.txt" ./build_bitcoin.sh

cat build/whyextract.txt
```

Look for (potentially) duplicated symbols/code.
This mostly flags duplicated code out of glibc.
```bash
llvm_toolchain/bin/llvm-nm -C --defined-only build/bin/bitcoind | awk '$2 ~ /^[rdbs]$/' | sort -u | cut -d' ' -f3- | sort | uniq -cd | sort -rn
  2 step4_jumps.3
  2 step4_jumps.0
  2 step3b_jumps.2
```

## PGO Collection
```bash
export PGO_FLAGS="-fprofile-generate=raw_pgo/ -fprofile-update=atomic"
CFLAGS="${PGO_FLAGS}" CXXFLAGS="${PGO_FLAGS}" LDFLAGS="${PGO_FLAGS}" ./build_bitcoin.sh

rm -rf /mnt/HC_Volume_104453609/btc_datadir/ && mkdir /mnt/HC_Volume_104453609/btc_datadir/

time ./build/bin/bitcoind -datadir=/mnt/HC_Volume_104453609/btc_datadir -dbcache=6144 -prune=2000 -stopatheight=950000 -daemon

llvm_toolchain/bin/llvm-profdata merge -o bitcoind.profdata raw_pgo/*.profraw
```

## BOLT instrumentation
```bash
export PGO_FLAGS="-fprofile-use=$(pwd)/bitcoind.profdata"
CFLAGS="${PGO_FLAGS}" CXXFLAGS="${PGO_FLAGS}" LDFLAGS="-Wl,--emit-relocs ${PGO_FLAGS}" ./build_bitcoin.sh

llvm_toolchain/bin/llvm-readelf -S build/bin/bitcoind | grep .rela.text # check relocs

llvm_toolchain/bin/llvm-bolt ./build/bin/bitcoind \
                             -instrument \
                             --instrumentation-sleep-time=1 \
                             --instrumentation-file=raw_bolt/prof.fdata \
                             -o bitcoind.instrumented

time ./bitcoind.instrumented -datadir=/mnt/HC_Volume_104453609/btc_datadir -dbcache=6144 -prune=2000 -stopatheight=950000 -daemon

# TODO: merge raw data from /tmp/prof.data into raw_bolt/
```

Investigate
```
BOLT-INFO: PointerAuthCFIAnalyzer ran on 10161 functions. Ignored 192 functions (1.89%) because of CFI inconsistencies
```

## Final Binary
```bash
./apply_bolt.sh

time ./bitcoind.bolt -datadir=/mnt/HC_Volume_104453609/btc_datadir -stopatheight=950000 -daemon
```

## Optimisation Report

Opt report generation:
```bash
/root/optview2/opt-viewer.py --jobs=10 \
      --collect-opt-success \
      --output-dir=/root/opt_report \
      --source-dir=/root/expert-potato/bitcoin \
      /root/expert-potato/build/bin/bitcoind-opt.ld.yaml
```

## TODO

- Add a "bloaty" analyse script
- Check PGO training coverage: `llvm_toolchain/bin/llvm-profdata show --all-functions
    --counts bitcoind.profdata | grep 'Counts: 0'` for hot-in-prod functions with no samples.
- Read through `-fsave-optimization-record` remarks (opt-viewer / llvm-opt-report),
    cross-referenced against `perf report` hot functions, for missed inlining/vectorization.
- Try an instrumented BOLT profile (`llvm-bolt -instrument`) vs the perf-derived one and
    compare `-dyno-stats` output.
- Measure `--icf=safe` vs `--icf=all` size delta (`--print-icf-sections`)

## Future

- The leftover `__aarch64_cas4_acq`-style outline-atomics symbols (should) go-away when we switch to
  a full LLVM libc build.