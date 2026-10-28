#!/usr/bin/env bash
#
# elmer.sh - Tier 3 smoke test: Elmer FEM 2D steady heat conduction.
#
# Builds a tiny 2D rectangular mesh, solves steady-state heat conduction
# (Laplace of temperature = 0 with two fixed-temperature boundaries) with
# ElmerSolver, and checks that a result file was produced.
#
# Exit codes: 0 PASS, 2 SKIP (ElmerGrid/ElmerSolver absent), other nonzero FAIL.
# Prints TIER=/VERSION=/NOTE= lines for the verify report.
set -euo pipefail

echo "TIER=3"

if ! command -v ElmerSolver >/dev/null 2>&1 || ! command -v ElmerGrid >/dev/null 2>&1; then
  echo "NOTE=Elmer (ElmerSolver/ElmerGrid) absent; apt elmerfem-csc in devcontainer/CI (apt-only)"
  echo "SKIP: Elmer not installed"
  exit 2
fi

VER="$(ElmerSolver --version 2>&1 | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

# A unit square meshed by ElmerGrid's built-in simple grid generator (.grd).
cat > heat.grd <<'GRD'
Version = 210903
Coordinate System = Cartesian 2D
Subcell Divisions in 2D = 1 1
Subcell Limits 1 = 0 1
Subcell Limits 2 = 0 1
Material Structure in 2D
  1
End
Materials Interval = 1 1
Boundary Definitions
  1 -1 1 1
  2 -2 1 1
  3 -3 1 1
  4 -4 1 1
End
Numbering = Horizontal
Element Degree = 1
Element Innernodes = False
Triangle Rule = 0
Surface Elements = 100
Coordinate Ratios = 1
Minimum Element Divisions = 4 4
Element Ratios 1 = 1
Element Ratios 2 = 1
GRD

# 2D steady heat conduction: left edge hot (373.15 K), right edge cold
# (273.15 K); the steady solution is a linear temperature profile.
cat > case.sif <<'SIF'
Header
  Mesh DB "." "heat"
End
Simulation
  Coordinate System = Cartesian 2D
  Simulation Type = Steady State
  Steady State Max Iterations = 1
  Output Intervals = 1
  Post File = "heat.vtu"
End
Body 1
  Equation = 1
  Material = 1
End
Equation 1
  Active Solvers(1) = 1
End
Solver 1
  Equation = "Heat Equation"
  Variable = "Temperature"
  Procedure = "HeatSolve" "HeatSolver"
  Linear System Solver = Direct
  Steady State Convergence Tolerance = 1.0e-6
End
Material 1
  Heat Conductivity = 1.0
  Density = 1.0
End
Boundary Condition 1
  Target Boundaries(1) = 4
  Temperature = 373.15
End
Boundary Condition 2
  Target Boundaries(1) = 2
  Temperature = 273.15
End
SIF

if ! ElmerGrid 1 2 heat.grd >grid.log 2>&1; then
  echo "NOTE=ElmerGrid failed to convert the .grd mesh"
  tail -n 15 grid.log || true
  echo "FAIL: ElmerGrid meshing failed"
  exit 1
fi

if ElmerSolver case.sif >solve.log 2>&1 && \
   { ls heat/*.vtu >/dev/null 2>&1 || grep -qi "ELMER SOLVER FINISHED" solve.log; }; then
  echo "PASS: Elmer solved 2D heat conduction"
  exit 0
fi

echo "NOTE=ElmerSolver did not finish cleanly or produced no result"
tail -n 15 solve.log || true
echo "FAIL: Elmer heat-conduction solve failed"
exit 1
