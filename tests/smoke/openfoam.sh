#!/usr/bin/env bash
#
# openfoam.sh - Tier 3 smoke test: OpenFOAM lid-driven cavity tutorial.
#
# Copies the classic incompressible cavity tutorial, meshes it with blockMesh,
# and runs the icoFoam solver for a few steps, then checks for a time directory
# of results. Uses the native OpenFOAM install (openfoam.org apt repo) when
# present; SKIPs when OpenFOAM is unavailable (the Docker-image fallback runs in
# CI where HAS_DOCKER=1, not exercised directly by this host-side test).
#
# Exit codes: 0 PASS, 2 SKIP (OpenFOAM absent), other nonzero FAIL.
# Prints TIER=/VERSION=/NOTE= lines for the verify report.
set -euo pipefail

echo "TIER=3"

# OpenFOAM sets up its environment via a shell function / bashrc. Try to source
# a common bashrc if the solver is not already on PATH.
if ! command -v icoFoam >/dev/null 2>&1; then
  for rc in /opt/openfoam*/etc/bashrc /usr/lib/openfoam/openfoam*/etc/bashrc; do
    # shellcheck source=/dev/null
    [ -f "${rc}" ] && . "${rc}" >/dev/null 2>&1 || true
  done
fi

if ! command -v icoFoam >/dev/null 2>&1 || ! command -v blockMesh >/dev/null 2>&1; then
  echo "NOTE=OpenFOAM (icoFoam/blockMesh) absent; openfoam.org apt repo in CI, else opencfd/openfoam-default Docker image (HAS_DOCKER)"
  echo "SKIP: OpenFOAM not installed"
  exit 2
fi

VER="$(icoFoam -help 2>&1 | sed -n 's/.*Build: \(.*\)/\1/p' | head -n1 || true)"
echo "VERSION=OpenFOAM ${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Locate the bundled cavity tutorial (path differs slightly across releases).
TUT=""
for base in "${FOAM_TUTORIALS:-}" /opt/openfoam*/tutorials /usr/share/openfoam/tutorials; do
  [ -z "${base}" ] && continue
  for cand in "${base}"/incompressible/icoFoam/cavity/cavity; do
    [ -d "${cand}" ] && TUT="${cand}" && break
  done
  [ -n "${TUT}" ] && break
done

if [ -z "${TUT}" ]; then
  echo "NOTE=cavity tutorial directory not found under FOAM_TUTORIALS"
  echo "SKIP: OpenFOAM present but cavity tutorial missing"
  exit 2
fi

cp -r "${TUT}" "${WORK}/cavity"
cd "${WORK}/cavity"

# Run only a few steps so the test stays within the 120s budget.
if [ -f system/controlDict ]; then
  sed -i 's/^endTime[[:space:]].*/endTime         0.05;/' system/controlDict || true
  sed -i 's/^writeInterval[[:space:]].*/writeInterval   0.01;/' system/controlDict || true
fi

if blockMesh >blockMesh.log 2>&1 && icoFoam >icoFoam.log 2>&1 \
     && ls -d [0-9]* 2>/dev/null | grep -qv '^0$'; then
  echo "PASS: OpenFOAM ran the cavity tutorial for a few steps"
  exit 0
fi

echo "NOTE=blockMesh/icoFoam failed or produced no time directories"
tail -n 15 icoFoam.log 2>/dev/null || tail -n 15 blockMesh.log 2>/dev/null || true
echo "FAIL: OpenFOAM cavity tutorial failed"
exit 1
