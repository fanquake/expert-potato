#!/usr/bin/env bash
set -euo pipefail

BITCOIND="build/bin/bitcoind"
BOLT="$(pwd)/llvm_toolchain/bin/llvm-bolt"
DATA="${1:-$(pwd)/raw_bolt/prof.fdata}"

BOLT_ARGS=(
  -dyno-stats
  -reorder-functions=cdsort
  -reorder-blocks=ext-tsp
  -split-functions
  -split-all-cold
  -split-eh
  --align-blocks
  --peepholes=all
  --icf=safe
  --inline-all
  --inline-memcpy
  --plt=hot
  --tail-duplication=aggressive
)

$BOLT $BITCOIND -o bitcoind.bolt -data=$DATA ${BOLT_ARGS[*]}