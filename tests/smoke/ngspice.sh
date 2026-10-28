#!/usr/bin/env bash
#
# ngspice.sh - Tier 6 smoke test: ngspice runs an RC transient analysis.
#
# Writes a minimal RC low-pass netlist (1k resistor + 1uF cap, step input),
# runs a transient analysis in batch mode (-b), and checks that the capacitor
# charges toward the source: V(out) at the end of the run should be within a
# few percent of the 1 V source and clearly above V(out) early in the run.
# Exit codes: 0 PASS, 2 SKIP (absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=6"

if ! command -v ngspice >/dev/null 2>&1; then
  echo "NOTE=ngspice absent on host; apt ngspice in devcontainer/CI"
  echo "SKIP: ngspice not installed"
  exit 2
fi

VER="$(ngspice --version 2>&1 | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# RC low-pass: tau = R*C = 1k * 1uF = 1 ms. Run 5 tau so V(out) ~ 0.993 V.
cat > "${WORK}/rc.cir" <<'SPICE'
* RC transient smoke test
V1 in 0 DC 1
R1 in out 1k
C1 out 0 1u
.tran 10u 5m
.control
run
* print the final out node voltage
meas tran vfinal FIND v(out) AT=5m
print vfinal
.endc
.end
SPICE

if ngspice -b "${WORK}/rc.cir" >"${WORK}/log" 2>&1; then
  # Extract the measured final voltage (vfinal = <value>).
  VFINAL="$(sed -n 's/.*vfinal[^0-9.-]*\([0-9][0-9.eE+-]*\).*/\1/p' "${WORK}/log" | tail -n1)"
  echo "NOTE=ngspice RC transient final V(out)=${VFINAL:-?} (expected ~0.993 V at 5 tau)"
  # Validate 0.95 <= vfinal <= 1.05 using awk (portable float compare).
  if [ -n "${VFINAL:-}" ] && awk -v v="${VFINAL}" 'BEGIN{exit !(v>=0.95 && v<=1.05)}'; then
    echo "PASS: ngspice RC transient charged the capacitor as expected"
    exit 0
  fi
  echo "FAIL: ngspice RC transient result out of range"
  tail -n 25 "${WORK}/log" || true
  exit 1
fi

echo "NOTE=ngspice batch run failed"
tail -n 25 "${WORK}/log" || true
echo "FAIL: ngspice run failed"
exit 1
