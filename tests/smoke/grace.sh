#!/usr/bin/env bash
#
# grace.sh - Tier 1 smoke test: Grace (gracebat/xmgrace) renders a trivial plot
# to PNG in batch (hardcopy) mode.
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=1"

GRACE=""
for c in gracebat xmgrace grace; do
  if command -v "$c" >/dev/null 2>&1; then GRACE="$c"; break; fi
done

if [ -z "${GRACE}" ]; then
  echo "NOTE=grace (gracebat) absent on host; apt grace in devcontainer/CI"
  echo "SKIP: grace not installed"
  exit 2
fi

VER="$(${GRACE} -version 2>&1 | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

printf '1 1\n2 4\n3 9\n' > "${WORK}/data.dat"

# gracebat is the non-interactive batch front end; xmgrace needs -hardcopy.
if "${GRACE}" -hardcopy -hdevice PNG -printfile "${WORK}/out.png" "${WORK}/data.dat" \
      >"${WORK}/log" 2>&1 && [ -s "${WORK}/out.png" ]; then
  echo "PASS: grace rendered PNG (batch)"
  exit 0
fi

echo "NOTE=grace batch render failed (needs X/PNG device?)"
tail -n 15 "${WORK}/log" || true
echo "FAIL: grace render failed"
exit 1
