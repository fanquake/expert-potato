# Core x LLVM

Working towards a self-contained build of Bitcoin Core with LLVM.
* Build using a self-compiled `23.x` Clang and `lld`.
* Use LLVM [`libc++`](https://libcxx.llvm.org/)
* Use LLVM [`libc` in overlay mode](https://libc.llvm.org/overlay_mode.html)
* Use [`scudo`](https://llvm.org/docs/ScudoHardenedAllocator.html) as an allocator
* Use [Profile Guided Optimization](https://clang.llvm.org/docs/UsersManual.html#profile-guided-optimization)
* Use [LLVM BOLT](https://github.com/llvm/llvm-project/blob/main/bolt/README.md)

```bash
git clone https://github.com/fanquake/core_x_llvm.git
cd core_x_llvm
git submodule update --init --depth 1

./build_llvm.sh
./build_depends.sh
./build_bitcoin.sh
./apply_bolt.sh
```

### TODO

- Add `-reindex`/`assumevalid=0` to `bench.conf`?
- Drop depends build if `boost::multi_index` is swapped for [`tmi2`](https://github.com/theuni/tmi2)
- Add a [`bloaty`](https://github.com/google/bloaty) analyse script
- Check PGO training coverage: `llvm_toolchain/bin/llvm-profdata show --all-functions
    --counts bitcoind.profdata | grep 'Counts: 0'` for hot-in-prod functions with no samples.
- Read through `-fsave-optimization-record` remarks (opt-viewer / llvm-opt-report),
    cross-referenced against `perf report` hot functions, for missed inlining/vectorization.
  - Re-add `-Wl,--opt-remarks-with-hotness`
- Try an instrumented BOLT profile (`llvm-bolt -instrument`) vs the perf-derived one and
    compare `-dyno-stats` output.
- Measure `--icf=safe` vs `--icf=all` size delta (`--print-icf-sections`)
- Generate some examples of optimisation flag usage and optview2 output
- Add a `samply` run: https://github.com/mstange/samply/

### Future

- The leftover `__aarch64_cas4_acq`-style outline-atomics symbols (should) go-away when we switch to
  a full LLVM libc build.

## llvm-project submodule

Tracking `release/23.x` (minimum for -static-pie in bolt):
```bash
git -C llvm-project fetch --depth 1 origin release/23.x
git -C llvm-project checkout FETCH_HEAD
git add llvm-project
git commit -m "llvm: update submodule to latest release/23.x"
```

## LLVM Components

```bash
LDFLAGS="-Wl,--why-extract=whyextract.txt" ./build_bitcoin.sh

# Did we get libc++
grep 'libc++' build/whyextract.txt

# Did we get LLVM libc
grep 'libllvmlibc.a' build/whyextract.txt
llvm_toolchain/bin/llvm-nm -C build/bin/bitcoind | grep __llvm_libc

# What came from libc.a
grep '/libc\.a' build/whyextract.txt

# Did we get scudo
llvm_toolchain/bin/llvm-nm -C build/bin/bitcoind | grep malloc
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

./build/bin/bitcoind -datadir=/mnt/HC_Volume_104453609/btc_datadir -conf=$(pwd)/bench.conf

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

./bitcoind.instrumented -datadir=/mnt/HC_Volume_104453609/btc_datadir -conf=$(pwd)/bench.conf

# TODO: merge raw data from /tmp/prof.data into raw_bolt/
```

Investigate
```
BOLT-INFO: PointerAuthCFIAnalyzer ran on 10161 functions. Ignored 192 functions (1.89%) because of CFI inconsistencies
```

## Final Binary
```bash
./apply_bolt.sh

./bitcoind.bolt -datadir=/mnt/HC_Volume_104453609/btc_datadir -conf=$(pwd)/bench.conf
tail -f /mnt/HC_Volume_104453609/btc_datadir/debug.log
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
