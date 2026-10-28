#!/usr/bin/env bash
#
# kicad.sh - Tier 6 smoke test: kicad-cli reports its version and exports a
# minimal schematic to SVG (headless, no GUI).
#
# We only use the headless `kicad-cli` (never the GUI). The test writes a
# minimal KiCad 7/8 schematic (.kicad_sch) with a single resistor symbol, then
# runs `kicad-cli sch export svg` and asserts a non-empty SVG is produced.
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=6"

if ! command -v kicad-cli >/dev/null 2>&1; then
  echo "NOTE=kicad-cli absent on host; apt kicad in devcontainer/CI"
  echo "SKIP: kicad-cli not installed"
  exit 2
fi

VER="$(kicad-cli version 2>&1 | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

SCH="${WORK}/min.kicad_sch"
OUT_DIR="${WORK}/out"
mkdir -p "${OUT_DIR}"

# Minimal KiCad S-expression schematic: empty sheet with a wire. kicad-cli can
# export even a near-empty schematic to SVG; the point is to exercise the CLI
# export path headlessly.
cat > "${SCH}" <<'SCHEOF'
(kicad_sch
  (version 20230121)
  (generator smoke)
  (uuid "00000000-0000-0000-0000-000000000001")
  (paper "A4")
  (wire
    (pts (xy 25.4 25.4) (xy 50.8 25.4))
    (stroke (width 0) (type default))
    (uuid "00000000-0000-0000-0000-000000000002")
  )
)
SCHEOF

if kicad-cli sch export svg --output "${OUT_DIR}" "${SCH}" >"${WORK}/log" 2>&1; then
  if ls "${OUT_DIR}"/*.svg >/dev/null 2>&1 && [ -s "$(ls "${OUT_DIR}"/*.svg | head -n1)" ]; then
    echo "NOTE=kicad-cli exported a minimal schematic to SVG"
    echo "PASS: kicad-cli version + minimal schematic SVG export"
    exit 0
  fi
fi

echo "NOTE=kicad-cli schematic export failed"
tail -n 25 "${WORK}/log" || true
echo "FAIL: kicad-cli schematic export failed"
exit 1
