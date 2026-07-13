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

Look for (potentially) duplicated symbols/code.
This mostly flags duplicated code out of glibc.
```bash
llvm_toolchain/bin/llvm-nm -C --defined-only build/bin/bitcoind | awk '$2 ~ /^[rdbs]$/' | sort -u | cut -d' ' -f3- | sort | uniq -cd | sort -rn
  2 step4_jumps.3
  2 step4_jumps.0
  2 step3b_jumps.2
```

Opt report generation:
```bash
/root/optview2/opt-viewer.py --jobs=10 \
      --collect-opt-success \
      --output-dir=/root/opt_report \
      --source-dir=/root/expert-potato/bitcoin \
      /root/expert-potato/build/bin/bitcoind-opt.ld.yaml
```

## Future

- The leftover `__aarch64_cas4_acq`-style outline-atomics symbols (should) go-away when we switch to
  a full LLVM libc build.


## TODO

- Check PGO training coverage: `llvm_toolchain/bin/llvm-profdata show --all-functions
    --counts bitcoind.profdata | grep 'Counts: 0'` for hot-in-prod functions with no samples.
- Read through `-fsave-optimization-record` remarks (opt-viewer / llvm-opt-report),
    cross-referenced against `perf report` hot functions, for missed inlining/vectorization.
- Try an instrumented BOLT profile (`llvm-bolt -instrument`) vs the perf-derived one and
    compare `-dyno-stats` output.
- Measure `--icf=safe` vs `--icf=all` size delta (`--print-icf-sections`)