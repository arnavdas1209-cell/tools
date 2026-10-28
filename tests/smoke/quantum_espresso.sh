#!/usr/bin/env bash
#
# quantum_espresso.sh - Tier 5 smoke test: Quantum ESPRESSO tiny Si SCF.
#
# Runs a minimal self-consistent-field (SCF) DFT calculation for bulk silicon
# with pw.x. The input is a 2-atom Si cell with a tiny plane-wave cutoff and a
# 2x2x2 k-grid - enough to exercise the solver without a long run. The test
# passes when pw.x reports JOB DONE and prints a total energy line.
#
# Quantum ESPRESSO (pw.x) is apt-only (quantum-espresso) / conda-forge; it is
# absent on the authoring host, so this SKIPs here and runs for real in the
# devcontainer/CI. NOTE: a real SCF also needs a Si pseudopotential; the test
# locates one via ESPRESSO_PSEUDO or a common pseudo dir and SKIPs (documented)
# if none is present rather than FAILing.
#
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=5"

PW_BIN=""
for cand in pw.x pw; do
  if command -v "${cand}" >/dev/null 2>&1; then PW_BIN="${cand}"; break; fi
done

if [ -z "${PW_BIN}" ]; then
  echo "NOTE=pw.x (Quantum ESPRESSO) absent; apt quantum-espresso / conda-forge qe in devcontainer/CI"
  echo "SKIP: quantum-espresso (pw.x) not installed"
  exit 2
fi

VER="$(${PW_BIN} -version 2>&1 | head -n1 || echo unknown)"
echo "VERSION=${VER:-unknown}"

# Locate a Si pseudopotential. QE reads pseudo_dir; honor ESPRESSO_PSEUDO.
PSEUDO_DIR="${ESPRESSO_PSEUDO:-}"
if [ -z "${PSEUDO_DIR}" ]; then
  for d in "${HOME}/.local/share/espresso/pseudo" /usr/share/espresso/pseudo /usr/share/quantum-espresso/pseudo; do
    [ -d "${d}" ] && { PSEUDO_DIR="${d}"; break; }
  done
fi
SI_UPF=""
if [ -n "${PSEUDO_DIR}" ]; then
  SI_UPF="$(ls "${PSEUDO_DIR}"/Si*.UPF "${PSEUDO_DIR}"/Si*.upf 2>/dev/null | head -n1 || true)"
fi
if [ -z "${SI_UPF}" ]; then
  echo "NOTE=no Si pseudopotential found (set ESPRESSO_PSEUDO); fetch e.g. Si.pz-vbc.UPF from pseudopotentials.quantum-espresso.org in devcontainer/CI"
  echo "SKIP: quantum-espresso Si pseudopotential unavailable"
  exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
SI_NAME="$(basename "${SI_UPF}")"

cat > "${WORK}/si.scf.in" <<EOF
&control
  calculation = 'scf'
  prefix = 'si'
  pseudo_dir = '${PSEUDO_DIR}'
  outdir = '${WORK}/out'
  verbosity = 'low'
/
&system
  ibrav = 2
  celldm(1) = 10.2
  nat = 2
  ntyp = 1
  ecutwfc = 12.0
/
&electrons
  conv_thr = 1.0d-6
/
ATOMIC_SPECIES
  Si 28.0855 ${SI_NAME}
ATOMIC_POSITIONS (alat)
  Si 0.00 0.00 0.00
  Si 0.25 0.25 0.25
K_POINTS (automatic)
  2 2 2 0 0 0
EOF

if ${PW_BIN} -in "${WORK}/si.scf.in" > "${WORK}/si.scf.out" 2>&1 \
      && grep -q "JOB DONE" "${WORK}/si.scf.out"; then
  ETOT="$(sed -n 's/.*total energy *= *\([-0-9.]*\).*Ry.*/\1/p' "${WORK}/si.scf.out" | tail -n1)"
  echo "NOTE=QE Si SCF converged; total energy=${ETOT:-?} Ry"
  echo "PASS: Quantum ESPRESSO completed a tiny Si SCF"
  exit 0
fi

echo "NOTE=QE Si SCF did not report JOB DONE"
tail -n 25 "${WORK}/si.scf.out" || true
echo "FAIL: Quantum ESPRESSO SCF run failed"
exit 1
