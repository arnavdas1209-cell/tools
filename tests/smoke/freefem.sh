#!/usr/bin/env bash
#
# freefem.sh - Tier 3 smoke test: FreeFEM++ Laplace solve.
#
# Solves the Laplace equation  -div(grad(u)) = 0  on the unit square with
# mixed Dirichlet BCs (u=0 on three edges, u=1 on one edge) and checks that
# the solution respects the maximum principle (0 <= u <= 1) and hits the BCs.
#
# Exit codes: 0 PASS, 2 SKIP (FreeFem++ absent), other nonzero FAIL.
# Prints TIER=/VERSION=/NOTE= lines for the verify report.
set -euo pipefail

echo "TIER=3"

FF=""
for cand in FreeFem++ freefem++ FreeFem++-nw; do
  if command -v "${cand}" >/dev/null 2>&1; then FF="${cand}"; break; fi
done

if [ -z "${FF}" ]; then
  echo "NOTE=FreeFEM (FreeFem++) absent; apt freefem++ in devcontainer/CI (apt-only)"
  echo "SKIP: FreeFem++ not installed"
  exit 2
fi

VER="$(${FF} 2>&1 | sed -n 's/.*version \([0-9.]*\).*/\1/p' | head -n1 || true)"
echo "VERSION=FreeFem++ ${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cat > "${WORK}/laplace.edp" <<'EDP'
// Laplace on the unit square: u=1 on the bottom edge, u=0 elsewhere.
mesh Th = square(20, 20);
fespace Vh(Th, P1);
Vh u, v;

solve Laplace(u, v)
  = int2d(Th)(dx(u)*dx(v) + dy(u)*dy(v))
  - int2d(Th)(0.0*v)
  + on(1, u=1.0)        // bottom edge
  + on(2, 3, 4, u=0.0); // right, top, left edges

real umin = u[].min;
real umax = u[].max;
cout << "UMIN " << umin << endl;
cout << "UMAX " << umax << endl;
// Maximum principle: harmonic solution stays within its boundary data.
if (umin >= -1e-6 && umax <= 1.0 + 1e-6 && umax > 0.5) {
  cout << "LAPLACE_OK" << endl;
} else {
  cout << "LAPLACE_BAD" << endl;
}
EDP

if ${FF} -nw "${WORK}/laplace.edp" >"${WORK}/log" 2>&1 && grep -q "LAPLACE_OK" "${WORK}/log"; then
  echo "PASS: FreeFEM Laplace solve satisfies the maximum principle"
  exit 0
fi

echo "NOTE=FreeFem++ Laplace solve failed or violated the maximum principle"
tail -n 15 "${WORK}/log" || true
echo "FAIL: FreeFEM Laplace solve failed"
exit 1
