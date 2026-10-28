#!/usr/bin/env bash
#
# scilab.sh - Tier 1 smoke test: scilab runs a trivial script (headless).
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=1"

SCILAB=""
for c in scilab-cli scilab-adv-cli scilab; do
  if command -v "$c" >/dev/null 2>&1; then SCILAB="$c"; break; fi
done

if [ -z "${SCILAB}" ]; then
  echo "NOTE=scilab absent on host; apt scilab in devcontainer/CI"
  echo "SKIP: scilab not installed"
  exit 2
fi

VER="$(${SCILAB} -version 2>/dev/null | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cat > "${WORK}/t.sce" <<'SCE'
x = sum(1:10);
disp(x);
quit;
SCE

OUT="$(${SCILAB} -nwni -nb -quit -f "${WORK}/t.sce" 2>/dev/null || true)"
if printf '%s' "${OUT}" | grep -q '55'; then
  echo "PASS: scilab computed sum(1:10)=55"
  exit 0
fi

echo "NOTE=unexpected scilab output: ${OUT}"
echo "FAIL: scilab trivial script failed"
exit 1
