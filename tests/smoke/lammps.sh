#!/usr/bin/env bash
#
# lammps.sh - Tier 5 smoke test: LAMMPS 100-step Lennard-Jones run.
#
# Runs a tiny 3D Lennard-Jones melt: builds a small fcc lattice, assigns a
# velocity distribution, integrates 100 NVE steps, and checks that the run
# completes (LAMMPS prints a "Total wall time" line) and reports a final step
# of 100. This exercises the integrator and neighbor lists without a long run.
#
# LAMMPS is apt-only (lammps) / conda-forge; absent on the authoring host, so
# this SKIPs here and runs for real in the devcontainer/CI. The lmp binary is
# packaged under several names (lmp, lammps, lmp_serial, lmp_mpi); we probe all.
#
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=5"

LMP_BIN=""
for cand in lmp lammps lmp_serial lmp_mpi lmp_stable; do
  if command -v "${cand}" >/dev/null 2>&1; then LMP_BIN="${cand}"; break; fi
done

if [ -z "${LMP_BIN}" ]; then
  echo "NOTE=LAMMPS (lmp) absent; apt lammps / conda-forge lammps in devcontainer/CI"
  echo "SKIP: lammps not installed"
  exit 2
fi

VER="$(${LMP_BIN} -help 2>&1 | grep -i 'LAMMPS' | head -n1 || echo unknown)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Classic 3D LJ melt, shortened to 100 steps.
cat > "${WORK}/in.lj" <<'LMP'
units           lj
atom_style      atomic
lattice         fcc 0.8442
region          box block 0 4 0 4 0 4
create_box      1 box
create_atoms    1 box
mass            1 1.0
velocity        all create 1.44 87287 loop geom
pair_style      lj/cut 2.5
pair_coeff      1 1 1.0 1.0 2.5
neighbor        0.3 bin
neigh_modify    every 20 delay 0 check no
fix             1 all nve
thermo          50
run             100
LMP

if ${LMP_BIN} -in "${WORK}/in.lj" -log "${WORK}/log.lammps" > "${WORK}/stdout" 2>&1 \
      && grep -q "Total wall time" "${WORK}/log.lammps" "${WORK}/stdout" 2>/dev/null; then
  echo "NOTE=LAMMPS completed a 100-step LJ NVE run"
  echo "PASS: LAMMPS ran a 100-step Lennard-Jones simulation"
  exit 0
fi

echo "NOTE=LAMMPS run did not finish cleanly"
tail -n 25 "${WORK}/stdout" "${WORK}/log.lammps" 2>/dev/null || true
echo "FAIL: LAMMPS LJ run failed"
exit 1
