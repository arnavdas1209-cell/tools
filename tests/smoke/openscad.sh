#!/usr/bin/env bash
#
# openscad.sh - Tier 1 smoke test: openscad exports a trivial cube to STL
# (headless; may need xvfb-run on some builds).
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=1"

if ! command -v openscad >/dev/null 2>&1; then
  echo "NOTE=openscad absent on host; apt openscad in devcontainer/CI"
  echo "SKIP: openscad not installed"
  exit 2
fi

VER="$(openscad --version 2>&1 | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

echo 'cube([10,10,10]);' > "${WORK}/c.scad"

run_scad() { openscad -o "${WORK}/c.stl" "${WORK}/c.scad"; }

if run_scad >"${WORK}/log" 2>&1 && [ -s "${WORK}/c.stl" ]; then
  echo "PASS: openscad exported STL"
  exit 0
fi
if command -v xvfb-run >/dev/null 2>&1 \
      && xvfb-run -a openscad -o "${WORK}/c.stl" "${WORK}/c.scad" >>"${WORK}/log" 2>&1 \
      && [ -s "${WORK}/c.stl" ]; then
  echo "PASS: openscad exported STL (under xvfb)"
  exit 0
fi

echo "NOTE=openscad export failed"
tail -n 15 "${WORK}/log" || true
echo "FAIL: openscad export failed"
exit 1
