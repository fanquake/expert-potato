#!/usr/bin/env bash
set -euo pipefail

BITCOIND="build/bin/bitcoind"
BOLT="$(pwd)/llvm_toolchain/bin/llvm-bolt"
DATA="${1:-$(pwd)/raw_bolt/prof.fdata}"

BOLT_ARGS=(
  -dyno-stats
  -lite=false
  -reorder-functions=cdsort
  -reorder-blocks=ext-tsp
  -split-functions
  -split-all-cold
  -split-eh
  --align-blocks
  --hugify
  --icf=safe
  --inline-all
  --inline-memcpy
  --peepholes=all
  --plt=hot
  --tail-duplication=aggressive
)

$BOLT $BITCOIND -o bitcoind.bolt -data=$DATA ${BOLT_ARGS[*]}