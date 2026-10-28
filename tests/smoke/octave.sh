#!/usr/bin/env bash
#
# octave.sh - Tier 1 smoke test: octave runs a trivial script.
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=1"

if ! command -v octave >/dev/null 2>&1; then
  echo "NOTE=octave absent on host; apt octave in devcontainer/CI"
  echo "SKIP: octave not installed"
  exit 2
fi

VER="$(octave --version 2>/dev/null | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

OUT="$(octave --no-gui --eval 'printf("%d\n", sum(1:10))' 2>/dev/null || true)"
if [ "${OUT//[[:space:]]/}" = "55" ]; then
  echo "PASS: octave computed sum(1:10)=55"
  exit 0
fi

echo "NOTE=unexpected octave output: ${OUT}"
echo "FAIL: octave trivial script failed"
exit 1
