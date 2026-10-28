#!/usr/bin/env bash
#
# freecad_step.sh - Tier 4 smoke test: FreeCADCmd (headless) creates a box and
# exports it to STEP.
#
# FreeCAD's console binary FreeCADCmd runs a Python script with the FreeCAD
# modules loaded, no GUI/X needed. We build a Part::Box and export it to a
# .step file via Import.export, then assert the file is non-empty.
#
# Named freecad_step.sh (NOT freecad.sh) to keep a clear, non-shadowing name.
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=4"

# FreeCAD ships the headless console binary as FreeCADCmd (sometimes freecadcmd).
FREECAD_BIN=""
for cand in FreeCADCmd freecadcmd FreeCADCmd.AppImage; do
  if command -v "${cand}" >/dev/null 2>&1; then FREECAD_BIN="${cand}"; break; fi
done

if [ -z "${FREECAD_BIN}" ]; then
  echo "NOTE=FreeCADCmd absent on host; apt freecad in devcontainer/CI"
  echo "SKIP: FreeCADCmd not installed"
  exit 2
fi

VER="$(${FREECAD_BIN} --version 2>&1 | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

STEP_OUT="${WORK}/box.step"
SCRIPT="${WORK}/make_box.py"

cat > "${SCRIPT}" <<PY
import FreeCAD as App
import Part

doc = App.newDocument("smoke")
box = doc.addObject("Part::Box", "Box")
box.Length = 10.0
box.Width = 20.0
box.Height = 30.0
doc.recompute()

out = r"${STEP_OUT}"
try:
    import Import
    Import.export([box], out)
except Exception:
    # Fall back to the shape's direct STEP exporter.
    box.Shape.exportStep(out)
print("exported", out)
PY

if ${FREECAD_BIN} "${SCRIPT}" >"${WORK}/log" 2>&1 && [ -s "${STEP_OUT}" ]; then
  # A valid STEP file starts with "ISO-10303-21".
  if head -n1 "${STEP_OUT}" | grep -q "ISO-10303-21"; then
    echo "NOTE=FreeCADCmd exported a 10x20x30 box to STEP (ISO-10303-21)"
    echo "PASS: FreeCADCmd created a box and exported STEP"
    exit 0
  fi
  echo "NOTE=STEP file written but header not recognized"
  echo "PASS: FreeCADCmd exported STEP (non-empty)"
  exit 0
fi

echo "NOTE=FreeCADCmd box/STEP export failed"
tail -n 20 "${WORK}/log" || true
echo "FAIL: FreeCADCmd box/STEP export failed"
exit 1
