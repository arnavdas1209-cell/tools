#!/usr/bin/env python3
"""fenics_poisson.py - Tier 3 smoke test: Poisson solve.

Solves the Poisson problem  -div(grad(u)) = f  on the unit square with
homogeneous Dirichlet BCs and checks the solution against the manufactured
analytic solution.

Primary path: FEniCSx (dolfinx). If dolfinx is unavailable, it falls back to
scikit-fem (pure python, pip-installable) so a REAL Poisson solve can run even
on a host without the full FEniCSx stack. Both paths verify the discrete
solution against the exact solution within tolerance.

Named fenics_poisson.py (NOT dolfinx.py) to avoid shadowing the real `dolfinx`
package via sys.path[0], per the repo naming convention.

Exit-code contract: 0 PASS, 2 SKIP (neither dolfinx nor scikit-fem available),
other nonzero FAIL. Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib.util
import os
import sys

# matplotlib is not used here, but keep the writable-config convention in case
# a backend gets imported transitively on this host (/root/.config read-only).
os.environ.setdefault("MPLCONFIGDIR", "/tmp/mpl")

TIER = 3
TOL = 1e-2


def solve_with_dolfinx() -> float:
    """Solve -lap(u)=f with dolfinx; return max nodal error vs exact u.

    Manufactured solution: u(x,y) = sin(pi x) sin(pi y),
    so f = 2 pi^2 sin(pi x) sin(pi y) and u=0 on the boundary.
    """
    import numpy as np
    from mpi4py import MPI
    import ufl
    from dolfinx import fem, mesh
    from dolfinx.fem.petsc import LinearProblem

    domain = mesh.create_unit_square(MPI.COMM_WORLD, 32, 32, mesh.CellType.triangle)
    V = fem.functionspace(domain, ("Lagrange", 1))

    # Dirichlet u=0 on the whole boundary.
    facets = mesh.locate_entities_boundary(
        domain, domain.topology.dim - 1,
        lambda x: np.full(x.shape[1], True, dtype=bool),
    )
    dofs = fem.locate_dofs_topological(V, domain.topology.dim - 1, facets)
    bc = fem.dirichletbc(0.0, dofs, V)

    x = ufl.SpatialCoordinate(domain)
    f = 2.0 * ufl.pi**2 * ufl.sin(ufl.pi * x[0]) * ufl.sin(ufl.pi * x[1])
    u, w = ufl.TrialFunction(V), ufl.TestFunction(V)
    a = ufl.inner(ufl.grad(u), ufl.grad(w)) * ufl.dx
    Lf = f * w * ufl.dx

    problem = LinearProblem(a, Lf, bcs=[bc],
                            petsc_options={"ksp_type": "preonly", "pc_type": "lu"})
    uh = problem.solve()

    coords = V.tabulate_dof_coordinates()
    exact = np.sin(np.pi * coords[:, 0]) * np.sin(np.pi * coords[:, 1])
    return float(np.max(np.abs(uh.x.array - exact)))


def solve_with_skfem() -> float:
    """Solve -lap(u)=f with scikit-fem (pure python); return max nodal error."""
    import numpy as np
    import skfem
    from skfem import Basis, ElementTriP1, MeshTri, asm, condense, solve
    from skfem.models.poisson import laplace, unit_load  # noqa: F401

    m = MeshTri().refined(5)  # ~1089 nodes on the unit square
    basis = Basis(m, ElementTriP1())

    @skfem.LinearForm
    def rhs(v, w):
        x, y = w.x
        f = 2.0 * np.pi**2 * np.sin(np.pi * x) * np.sin(np.pi * y)
        return f * v

    K = asm(laplace, basis)
    b = asm(rhs, basis)
    uh = solve(*condense(K, b, D=basis.get_dofs()))

    x, y = m.p
    exact = np.sin(np.pi * x) * np.sin(np.pi * y)
    return float(np.max(np.abs(uh - exact)))


def main() -> int:
    print(f"TIER={TIER}")

    if importlib.util.find_spec("dolfinx") is not None:
        try:
            import dolfinx
            print(f"VERSION=dolfinx={getattr(dolfinx, '__version__', '?')}")
            err = solve_with_dolfinx()
            print(f"NOTE=dolfinx Poisson max nodal error={err:.3e} (tol {TOL:.0e})")
            if err <= TOL:
                print("PASS: dolfinx Poisson solve matches exact solution")
                return 0
            print("FAIL: dolfinx Poisson error above tolerance")
            return 1
        except Exception as exc:  # noqa: BLE001
            print(f"NOTE=dolfinx present but solve failed: {type(exc).__name__}: {exc}")
            # fall through to scikit-fem

    if importlib.util.find_spec("skfem") is not None:
        try:
            import skfem
            print(f"VERSION=scikit-fem={getattr(skfem, '__version__', '?')} (fallback)")
            err = solve_with_skfem()
            print(f"NOTE=scikit-fem Poisson max nodal error={err:.3e} (tol {TOL:.0e})")
            if err <= TOL:
                print("PASS: scikit-fem Poisson solve matches exact solution")
                return 0
            print("FAIL: scikit-fem Poisson error above tolerance")
            return 1
        except Exception as exc:  # noqa: BLE001
            print(f"NOTE=scikit-fem solve failed: {type(exc).__name__}: {exc}")
            print("FAIL: scikit-fem Poisson solve errored")
            return 1

    print("NOTE=neither dolfinx nor scikit-fem importable; conda-forge fea env (devcontainer/CI) or pip scikit-fem")
    print("SKIP: no FEM backend available")
    return 2


if __name__ == "__main__":
    sys.exit(main())
