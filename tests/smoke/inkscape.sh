#!/usr/bin/env bash
#
# inkscape.sh - Tier 1 smoke test: inkscape converts an SVG to PDF.
#
# Exit codes: 0 PASS, 2 SKIP (inkscape absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=1"

if ! command -v inkscape >/dev/null 2>&1; then
  echo "NOTE=inkscape absent on host; apt inkscape in devcontainer/CI (headless)"
  echo "SKIP: inkscape not installed"
  exit 2
fi

VER="$(inkscape --version 2>/dev/null | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cat > "${WORK}/in.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="100" height="60">
  <rect x="5" y="5" width="90" height="50" fill="#4c78a8"/>
  <text x="12" y="35" fill="white" font-size="14">OK</text>
</svg>
SVG

# Inkscape 1.x syntax; fall back to 0.9x --export-pdf if the new flags fail.
if inkscape "${WORK}/in.svg" --export-type=pdf --export-filename="${WORK}/out.pdf" \
      >"${WORK}/log" 2>&1 && [ -s "${WORK}/out.pdf" ]; then
  echo "PASS: inkscape svg->pdf"
  exit 0
fi
if inkscape "${WORK}/in.svg" --export-pdf="${WORK}/out.pdf" >>"${WORK}/log" 2>&1 \
      && [ -s "${WORK}/out.pdf" ]; then
  echo "PASS: inkscape svg->pdf (legacy flags)"
  exit 0
fi

echo "NOTE=inkscape svg->pdf export failed"
tail -n 15 "${WORK}/log" || true
echo "FAIL: inkscape export failed"
exit 1
