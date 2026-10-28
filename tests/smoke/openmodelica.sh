#!/usr/bin/env bash
#
# openmodelica.sh - Tier 4 smoke test: OpenModelica compiles+simulates a trivial
# model via the `omc` command-line compiler.
#
# Writes a tiny Modelica model (a first-order ODE, der(x) = -x) plus an omc
# script that loads it, simulates a short interval and checks the solver ran.
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=4"

if ! command -v omc >/dev/null 2>&1; then
  echo "NOTE=omc (OpenModelica) absent on host; official apt repo in devcontainer/CI"
  echo "SKIP: OpenModelica (omc) not installed"
  exit 2
fi

VER="$(omc --version 2>&1 | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

cat > Decay.mo <<'MO'
model Decay
  Real x(start = 1.0);
equation
  der(x) = -x;
end Decay;
MO

cat > run.mos <<'MOS'
loadFile("Decay.mo");
getErrorString();
simulate(Decay, stopTime = 1.0, numberOfIntervals = 10);
getErrorString();
MOS

if omc run.mos >"${WORK}/log" 2>&1; then
  # A successful simulate() prints a resultFile entry and produces a .mat file.
  if grep -q "resultFile" "${WORK}/log" || ls "${WORK}"/Decay_res.* >/dev/null 2>&1; then
    echo "NOTE=omc compiled+simulated Decay (der(x)=-x)"
    echo "PASS: OpenModelica simulated a trivial model"
    exit 0
  fi
fi

echo "NOTE=omc simulate failed"
tail -n 20 "${WORK}/log" || true
echo "FAIL: OpenModelica simulate failed"
exit 1
