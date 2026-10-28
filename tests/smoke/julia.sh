#!/usr/bin/env bash
#
# julia.sh - Tier 4 smoke test: Julia runs a trivial script.
#
# Julia is installed via juliaup in scripts/40_binaries.sh. This test runs a
# one-line program that performs an arithmetic check and prints a sentinel; it
# also looks for a julia launcher under ~/.juliaup/bin if not on PATH.
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=4"

JULIA_BIN=""
if command -v julia >/dev/null 2>&1; then
  JULIA_BIN="julia"
elif [ -x "${HOME}/.juliaup/bin/julia" ]; then
  JULIA_BIN="${HOME}/.juliaup/bin/julia"
fi

if [ -z "${JULIA_BIN}" ]; then
  echo "NOTE=julia absent on host; installed via juliaup (scripts/40_binaries.sh) in devcontainer/CI"
  echo "SKIP: julia not installed"
  exit 2
fi

VER="$(${JULIA_BIN} --version 2>&1 | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Trivial script: compute a sum and assert it, then print a sentinel.
cat > "${WORK}/trivial.jl" <<'JL'
s = sum(1:10)
@assert s == 55 "arithmetic check failed"
println("JULIA_SMOKE_OK ", s)
JL

if ${JULIA_BIN} --startup-file=no "${WORK}/trivial.jl" >"${WORK}/log" 2>&1 \
      && grep -q "JULIA_SMOKE_OK 55" "${WORK}/log"; then
  echo "NOTE=julia ran a trivial script (sum(1:10)==55)"
  echo "PASS: Julia executed a trivial script"
  exit 0
fi

echo "NOTE=julia trivial script failed"
tail -n 20 "${WORK}/log" || true
echo "FAIL: Julia trivial script failed"
exit 1
