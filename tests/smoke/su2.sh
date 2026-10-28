#!/usr/bin/env bash
#
# su2.sh - Tier 3 smoke test: SU2 tiny inviscid (Euler) case.
#
# Generates a small structured quad mesh in SU2 native (.su2) format and runs
# SU2_CFD for a handful of Euler iterations, then checks that a history/restart
# file was produced. Kept intentionally tiny so it finishes within 120s.
#
# Exit codes: 0 PASS, 2 SKIP (SU2_CFD absent), other nonzero FAIL.
# Prints TIER=/VERSION=/NOTE= lines for the verify report.
set -euo pipefail

echo "TIER=3"

if ! command -v SU2_CFD >/dev/null 2>&1; then
  echo "NOTE=SU2 (SU2_CFD) absent; conda-forge su2 in fea env (devcontainer/CI) or SU2 release binaries"
  echo "SKIP: SU2_CFD not installed"
  exit 2
fi

VER="$(SU2_CFD 2>&1 | sed -n 's/.*Version \([0-9.]*\).*/\1/p' | head -n1 || true)"
echo "VERSION=SU2 ${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

# A minimal 2x2-cell structured quad mesh on the unit square in SU2 format.
cat > mesh.su2 <<'MESH'
NDIME= 2
NELEM= 4
9 0 1 4 3 0
9 1 2 5 4 1
9 3 4 7 6 2
9 4 5 8 7 3
NPOIN= 9
0.0 0.0 0
0.5 0.0 1
1.0 0.0 2
0.0 0.5 3
0.5 0.5 4
1.0 0.5 5
0.0 1.0 6
0.5 1.0 7
1.0 1.0 8
NMARK= 4
MARKER_TAG= inlet
MARKER_ELEMS= 2
3 0 3
3 3 6
MARKER_TAG= outlet
MARKER_ELEMS= 2
3 2 5
3 5 8
MARKER_TAG= lower
MARKER_ELEMS= 2
3 0 1
3 1 2
MARKER_TAG= upper
MARKER_ELEMS= 2
3 6 7
3 7 8
MESH

# Tiny inviscid (Euler) config: just a few iterations.
cat > euler.cfg <<'CFG'
SOLVER= EULER
MATH_PROBLEM= DIRECT
MACH_NUMBER= 0.3
AOA= 0.0
FREESTREAM_PRESSURE= 101325.0
FREESTREAM_TEMPERATURE= 288.15
MARKER_EULER= ( lower, upper )
MARKER_FAR= ( inlet, outlet )
NUM_METHOD_GRAD= GREEN_GAUSS
CFL_NUMBER= 1.0
ITER= 5
CONV_NUM_METHOD_FLOW= JST
TIME_DISCRE_FLOW= EULER_IMPLICIT
MESH_FILENAME= mesh.su2
MESH_FORMAT= SU2
OUTPUT_FILES= ( RESTART, HISTORY )
CONV_FILENAME= history
RESTART_FILENAME= restart_flow.dat
CFG

if SU2_CFD euler.cfg >su2.log 2>&1 \
     && { ls restart_flow* >/dev/null 2>&1 || ls history* >/dev/null 2>&1; }; then
  echo "PASS: SU2 ran a tiny inviscid case"
  exit 0
fi

echo "NOTE=SU2_CFD failed or produced no restart/history output"
tail -n 15 su2.log || true
echo "FAIL: SU2 inviscid case failed"
exit 1
