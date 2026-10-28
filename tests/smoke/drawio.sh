#!/usr/bin/env bash
#
# drawio.sh - Tier 1 smoke test: drawio-desktop exports a diagram to PDF under
# a virtual framebuffer (xvfb-run) on a headless host.
#
# Exit codes: 0 PASS, 2 SKIP (drawio or xvfb-run absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=1"

DRAWIO=""
for c in drawio drawio-desktop; do
  if command -v "$c" >/dev/null 2>&1; then DRAWIO="$c"; break; fi
done

if [ -z "${DRAWIO}" ]; then
  echo "NOTE=drawio-desktop absent on host; scripts/30_node.sh installs it in devcontainer/CI"
  echo "SKIP: drawio not installed"
  exit 2
fi
if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "NOTE=xvfb-run absent; apt xvfb needed for headless drawio export (devcontainer/CI)"
  echo "SKIP: xvfb-run not installed"
  exit 2
fi

VER="$(${DRAWIO} --version 2>/dev/null | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Minimal valid mxGraph diagram with a single box.
cat > "${WORK}/in.drawio" <<'XML'
<mxfile><diagram id="d1" name="Page-1">
<mxGraphModel dx="800" dy="600" grid="1" gridSize="10" guides="1" tooltips="1"
  connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="850"
  pageHeight="1100" math="0" shadow="0">
<root>
  <mxCell id="0"/><mxCell id="1" parent="0"/>
  <mxCell id="2" value="Box" style="rounded=0;whiteSpace=wrap;html=1;"
    vertex="1" parent="1">
    <mxGeometry x="200" y="160" width="120" height="60" as="geometry"/>
  </mxCell>
</root>
</mxGraphModel>
</diagram></mxfile>
XML

if xvfb-run -a "${DRAWIO}" --no-sandbox -x -f pdf -o "${WORK}/out.pdf" "${WORK}/in.drawio" \
      >"${WORK}/log" 2>&1 && [ -s "${WORK}/out.pdf" ]; then
  echo "PASS: drawio exported PDF under xvfb"
  exit 0
fi

echo "NOTE=drawio headless export failed; see log"
tail -n 15 "${WORK}/log" || true
echo "FAIL: drawio export failed"
exit 1
