#!/usr/bin/env bash
#
# code_aster.sh - Tier 3 smoke test: tiny linear-elastic Code_Aster case.
#
# Writes a minimal Code_Aster command file (.comm) for a trivial linear-elastic
# static study and runs it headless through scripts/run_aster.sh, which drives
# the official Code_Aster container (Apptainer preferred, Docker fallback).
#
# Code_Aster has no clean headless apt/conda path, so it runs via a container.
# When no working container runtime exists (the Amazon Linux 2023 host: broken
# podman shim + no apptainer -> CONTAINER_RUNTIME=none), run_aster.sh exits 2
# and this test reports SKIP. Documented in docs/UNSUPPORTED.md.
#
# Exit codes: 0 PASS, 2 SKIP (no container runtime), other nonzero FAIL.
# Prints TIER=/VERSION=/NOTE= lines for the verify report.
set -euo pipefail

echo "TIER=3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RUN_ASTER="${REPO_ROOT}/scripts/run_aster.sh"

if [ ! -x "${RUN_ASTER}" ]; then
  echo "NOTE=scripts/run_aster.sh missing or not executable"
  echo "FAIL: run_aster.sh wrapper unavailable"
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Minimal linear-elastic static command file. The mesh would normally be
# supplied via the .export; this is a tiny self-contained elastic study used to
# prove the Code_Aster toolchain executes headless end to end.
cat > "${WORK}/elastic.comm" <<'COMM'
DEBUT()

MA = LIRE_MAILLAGE(FORMAT='MED')

MO = AFFE_MODELE(MAILLAGE=MA,
                 AFFE=_F(TOUT='OUI',
                         PHENOMENE='MECANIQUE',
                         MODELISATION='3D'))

MAT = DEFI_MATERIAU(ELAS=_F(E=210.0E9, NU=0.3))

CHMAT = AFFE_MATERIAU(MAILLAGE=MA,
                      AFFE=_F(TOUT='OUI', MATER=MAT))

CLIM = AFFE_CHAR_MECA(MODELE=MO,
                      DDL_IMPO=_F(GROUP_MA='FIX', DX=0.0, DY=0.0, DZ=0.0))

CHAR = AFFE_CHAR_MECA(MODELE=MO,
                      FORCE_FACE=_F(GROUP_MA='LOAD', FZ=-1.0E3))

RESU = MECA_STATIQUE(MODELE=MO,
                     CHAM_MATER=CHMAT,
                     EXCIT=(_F(CHARGE=CLIM), _F(CHARGE=CHAR)))

RESU = CALC_CHAMP(reuse=RESU, RESULTAT=RESU,
                  CONTRAINTE='SIGM_ELNO')

FIN()
COMM

# Delegate to the wrapper. It exits 2 (SKIP) when no container runtime is
# available, which this test propagates as SKIP per the honesty rule.
set +e
"${RUN_ASTER}" "${WORK}/elastic.comm" >"${WORK}/aster.log" 2>&1
rc=$?
set -e

if [ "${rc}" -eq 2 ]; then
  echo "NOTE=Code_Aster needs a container runtime (none here); official image via Apptainer/Docker in CI. See docs/UNSUPPORTED.md"
  echo "SKIP: no container runtime for Code_Aster"
  exit 2
fi

if [ "${rc}" -eq 0 ]; then
  echo "VERSION=Code_Aster (container image via run_aster.sh)"
  echo "PASS: Code_Aster ran the tiny elastic case"
  exit 0
fi

echo "NOTE=run_aster.sh returned ${rc}"
tail -n 15 "${WORK}/aster.log" 2>/dev/null || true
echo "FAIL: Code_Aster elastic case failed"
exit 1
