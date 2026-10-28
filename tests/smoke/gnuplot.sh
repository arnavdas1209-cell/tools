#!/usr/bin/env bash
#
# gnuplot.sh - Tier 1 smoke test: gnuplot renders a trivial PNG (dumb/png term).
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=1"

if ! command -v gnuplot >/dev/null 2>&1; then
  echo "NOTE=gnuplot absent on host; apt gnuplot in devcontainer/CI"
  echo "SKIP: gnuplot not installed"
  exit 2
fi

VER="$(gnuplot --version 2>/dev/null | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Prefer a PNG output; fall back to the dumb (ASCII) terminal if no PNG support.
if gnuplot -e "set terminal pngcairo; set output '${WORK}/p.png'; plot sin(x)" \
      >"${WORK}/log" 2>&1 && [ -s "${WORK}/p.png" ]; then
  echo "PASS: gnuplot rendered PNG"
  exit 0
fi
if gnuplot -e "set terminal dumb; plot sin(x)" >"${WORK}/out" 2>&1 \
      && [ -s "${WORK}/out" ]; then
  echo "PASS: gnuplot rendered (dumb terminal)"
  exit 0
fi

echo "NOTE=gnuplot failed to render"
tail -n 15 "${WORK}/log" 2>/dev/null || true
echo "FAIL: gnuplot render failed"
exit 1
