#!/usr/bin/env bash
#
# openbabel.sh - Tier 2 smoke test: Open Babel converts SMILES to mol2.
#
# Exit codes: 0 PASS, 2 SKIP (obabel absent), other nonzero FAIL.
# Prints TIER=/VERSION=/NOTE= lines for the verify report.
set -euo pipefail

echo "TIER=2"

if ! command -v obabel >/dev/null 2>&1; then
  echo "NOTE=openbabel (obabel) absent on host; conda-forge openbabel in chem env (devcontainer/CI)"
  echo "SKIP: obabel not installed"
  exit 2
fi

VER="$(obabel -V 2>&1 | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Aspirin SMILES -> mol2 (generate 3D coords so the mol2 has real geometry).
SMILES="CC(=O)OC1=CC=CC=C1C(=O)O"

if obabel -:"${SMILES}" -omol2 -O "${WORK}/mol.mol2" --gen3d \
      >"${WORK}/log" 2>&1 && [ -s "${WORK}/mol.mol2" ] \
      && grep -q "@<TRIPOS>MOLECULE" "${WORK}/mol.mol2"; then
  echo "PASS: obabel SMILES->mol2"
  exit 0
fi

echo "NOTE=obabel SMILES->mol2 conversion failed or produced invalid mol2"
tail -n 15 "${WORK}/log" || true
echo "FAIL: openbabel conversion failed"
exit 1
