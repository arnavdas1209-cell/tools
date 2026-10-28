#!/usr/bin/env bash
#
# gromacs.sh - Tier 5 smoke test: GROMACS version + tiny self-check.
#
# Reports the GROMACS version (gmx --version) and runs a lightweight internal
# check: `gmx --version` must succeed and print a GROMACS version line, and we
# exercise a trivial tool (`gmx pdb2gmx -h` help, or `gmx check`) to confirm the
# toolkit is functional headlessly. GROMACS is apt-only (gromacs) /
# conda-forge; absent on the authoring host, so this SKIPs here and runs for
# real in the devcontainer/CI. The driver is usually `gmx` (or `gmx_mpi`).
#
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=5"

GMX_BIN=""
for cand in gmx gmx_mpi gmx_d; do
  if command -v "${cand}" >/dev/null 2>&1; then GMX_BIN="${cand}"; break; fi
done

if [ -z "${GMX_BIN}" ]; then
  echo "NOTE=GROMACS (gmx) absent; apt gromacs / conda-forge gromacs in devcontainer/CI"
  echo "SKIP: gromacs not installed"
  exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# `gmx --version` prints a "GROMACS version" line when the toolkit is healthy.
if ${GMX_BIN} --version > "${WORK}/ver" 2>&1; then
  VER="$(sed -n 's/.*GROMACS version:[[:space:]]*\(.*\)/\1/p' "${WORK}/ver" | head -n1)"
  [ -z "${VER}" ] && VER="$(grep -i 'GROMACS' "${WORK}/ver" | head -n1)"
  echo "VERSION=${VER:-unknown}"
else
  echo "NOTE=gmx --version failed"
  tail -n 20 "${WORK}/ver" || true
  echo "FAIL: gromacs version query failed"
  exit 1
fi

# Tiny functional check: the help for a core tool must run without error.
if ${GMX_BIN} help commands > "${WORK}/cmds" 2>&1 \
      || ${GMX_BIN} pdb2gmx -h > "${WORK}/cmds" 2>&1; then
  echo "NOTE=GROMACS version reported and a core tool responded to a help query"
  echo "PASS: GROMACS version + tiny self-check succeeded"
  exit 0
fi

echo "NOTE=GROMACS core tool help query failed"
tail -n 20 "${WORK}/cmds" || true
echo "FAIL: gromacs self-check failed"
exit 1
