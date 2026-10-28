#!/usr/bin/env python3
"""calculix.py - Tier 3 smoke test: gmsh-meshed cantilever beam in CalculiX.

Builds a 3D cantilever beam, meshes it with Gmsh (python `gmsh` module),
writes a CalculiX input deck, solves it with the ccx solver, parses the
maximum tip displacement from the .dat/.frd output, and compares it to the
Euler-Bernoulli analytic tip deflection:

    delta = F * L**3 / (3 * E * I)        with  I = b * h**3 / 12

PASS only when the solved max displacement is within 5% of this analytic value.

Named calculix.py (it imports `gmsh`, not a package named `calculix`, so there
is no self-shadowing risk here).

Exit-code contract: 0 PASS, 2 SKIP (gmsh python module or ccx solver absent),
other nonzero FAIL (e.g. solved displacement outside the 5% tolerance).
Prints TIER=/VERSION=/NOTE= lines for the verify report.

ENVIRONMENT NOTE: on the Amazon Linux 2023 validation host the ccx solver is
apt-only and absent, so this test SKIPs. The `gmsh` PyPI wheel may let the mesh
step run, but without ccx the solve cannot execute -> SKIP (exit 2). The
analytic comparison below is written so a reviewer can confirm correctness even
when the solver is unavailable here; it runs for real in the devcontainer/CI.
"""
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile

TIER = 3

# --- beam geometry and material (SI units: m, N, Pa) ------------------------
L = 1.0        # length (m)
B = 0.05       # width  (m)
H = 0.05       # height (m)
E = 210.0e9    # Young's modulus, steel (Pa)
NU = 0.3       # Poisson ratio
F = 1000.0     # tip load (N), applied in -z

# Euler-Bernoulli second moment of area for a rectangular section (bending
# about the width axis, load in the thickness/height direction):
I = B * H**3 / 12.0
# Analytic tip deflection of a cantilever with an end point load:
ANALYTIC_DELTA = F * L**3 / (3.0 * E * I)
TOL = 0.05     # 5% tolerance


def analytic_deflection() -> float:
    """Return the Euler-Bernoulli cantilever tip deflection, delta = F L^3/(3 E I)."""
    second_moment = B * H**3 / 12.0
    return F * L**3 / (3.0 * E * second_moment)


def within_tolerance(numeric: float, analytic: float, tol: float = TOL) -> bool:
    """True iff |numeric| is within `tol` (fractional) of |analytic|."""
    if analytic == 0:
        return abs(numeric) <= tol
    return abs(abs(numeric) - abs(analytic)) / abs(analytic) <= tol


def build_mesh(work: str):
    """Mesh the cantilever with Gmsh; return (node_coords, elements, nodesets)."""
    import gmsh

    gmsh.initialize()
    gmsh.option.setNumber("General.Terminal", 0)
    gmsh.model.add("cantilever")
    # Box from origin extending along +x (length), with cross-section b x h.
    gmsh.model.occ.addBox(0, 0, 0, L, B, H)
    gmsh.model.occ.synchronize()
    # A coarse-but-valid second-order tet mesh is enough for a smoke test.
    gmsh.option.setNumber("Mesh.MeshSizeMax", H / 2.0)
    gmsh.model.mesh.generate(3)
    gmsh.model.mesh.setOrder(2)

    node_tags, node_coords, _ = gmsh.model.mesh.getNodes()
    coords = {
        int(t): (node_coords[3 * i], node_coords[3 * i + 1], node_coords[3 * i + 2])
        for i, t in enumerate(node_tags)
    }
    # C3D10 (10-node tet) connectivity.
    etypes, etags, enodes = gmsh.model.mesh.getElements(dim=3)
    elements = []
    for etype, tags, conn in zip(etypes, etags, enodes):
        npe = gmsh.model.mesh.getElementProperties(etype)[3]
        for k, tag in enumerate(tags):
            nodes = [int(conn[k * npe + j]) for j in range(npe)]
            elements.append((int(tag), nodes))
    gmsh.finalize()

    # Node sets: fixed face at x=0, loaded face at x=L.
    tol = 1e-6
    fixed = [t for t, (x, _, _) in coords.items() if abs(x - 0.0) < tol]
    loaded = [t for t, (x, _, _) in coords.items() if abs(x - L) < tol]
    return coords, elements, fixed, loaded


def write_ccx_deck(work: str, coords, elements, fixed, loaded) -> str:
    """Write a CalculiX .inp deck; return its path (without extension)."""
    inp = os.path.join(work, "beam.inp")
    nodal_force = -F / max(len(loaded), 1)  # distribute the tip load over -z
    with open(inp, "w") as fh:
        fh.write("*NODE\n")
        for t, (x, y, z) in sorted(coords.items()):
            fh.write(f"{t}, {x:.8e}, {y:.8e}, {z:.8e}\n")
        fh.write("*ELEMENT, TYPE=C3D10, ELSET=EALL\n")
        for tag, nodes in elements:
            fh.write(f"{tag}, " + ", ".join(str(n) for n in nodes) + "\n")
        fh.write("*NSET, NSET=NFIX\n")
        fh.write(", ".join(str(n) for n in fixed) + ",\n")
        fh.write("*NSET, NSET=NLOAD\n")
        fh.write(", ".join(str(n) for n in loaded) + ",\n")
        fh.write("*MATERIAL, NAME=STEEL\n*ELASTIC\n")
        fh.write(f"{E:.6e}, {NU}\n")
        fh.write("*SOLID SECTION, ELSET=EALL, MATERIAL=STEEL\n")
        fh.write("*STEP\n*STATIC\n")
        fh.write("*BOUNDARY\nNFIX, 1, 3\n")  # clamp all DOF on the fixed face
        fh.write("*CLOAD\n")
        fh.write(f"NLOAD, 3, {nodal_force:.6e}\n")  # load in -z on each loaded node
        fh.write("*NODE PRINT, NSET=NLOAD\nU\n")
        fh.write("*END STEP\n")
    return inp[:-4]  # ccx wants the job name without the .inp suffix


def parse_max_disp(dat_path: str) -> float:
    """Parse the max |U3| (z-displacement) from a CalculiX .dat file."""
    max_uz = 0.0
    with open(dat_path) as fh:
        in_disp = False
        for line in fh:
            s = line.strip()
            if s.lower().startswith("displacements"):
                in_disp = True
                continue
            if in_disp:
                parts = s.split()
                # rows look like: node  u1  u2  u3
                if len(parts) >= 4:
                    try:
                        uz = float(parts[3])
                    except ValueError:
                        continue
                    max_uz = max(max_uz, abs(uz))
                elif s == "":
                    in_disp = False
    return max_uz


def main() -> int:
    print(f"TIER={TIER}")
    analytic = analytic_deflection()
    print(f"NOTE=analytic cantilever tip deflection delta=F*L^3/(3*E*I)={analytic:.6e} m (tol {TOL*100:.0f}%)")

    # Need BOTH the gmsh python module (to mesh) and the ccx solver (to solve).
    if importlib.util.find_spec("gmsh") is None:
        print("NOTE=gmsh python module absent; apt gmsh / conda-forge in fea env (devcontainer/CI)")
        print("SKIP: gmsh not importable")
        return 2
    ccx = shutil.which("ccx") or shutil.which("ccx_2.21") or shutil.which("ccx_2.20")
    if ccx is None:
        print("NOTE=CalculiX solver (ccx) absent; apt calculix-ccx in devcontainer/CI (apt-only, not on PyPI)")
        print("SKIP: ccx solver not installed")
        return 2

    try:
        import gmsh
        print(f"VERSION=gmsh={gmsh.__version__ if hasattr(gmsh, '__version__') else '?'}; ccx={ccx}")
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE=gmsh import failed: {type(exc).__name__}: {exc}")
        print("SKIP: gmsh not usable")
        return 2

    work = tempfile.mkdtemp(prefix="ccx_beam_")
    try:
        coords, elements, fixed, loaded = build_mesh(work)
        if not elements or not fixed or not loaded:
            print("NOTE=meshing produced no elements or empty node sets")
            print("FAIL: mesh generation failed")
            return 1
        job = write_ccx_deck(work, coords, elements, fixed, loaded)
        proc = subprocess.run(
            [ccx, os.path.basename(job)],
            cwd=work, capture_output=True, text=True, timeout=100,
        )
        dat = job + ".dat"
        if proc.returncode != 0 or not os.path.isfile(dat):
            print(f"NOTE=ccx returned {proc.returncode}; {proc.stdout[-300:]}")
            print("FAIL: ccx solve failed")
            return 1
        numeric = parse_max_disp(dat)
        print(f"NOTE=ccx max |U_z|={numeric:.6e} m vs analytic {analytic:.6e} m")
        if numeric <= 0.0:
            print("FAIL: ccx produced no displacement")
            return 1
        if within_tolerance(numeric, analytic):
            rel = abs(abs(numeric) - abs(analytic)) / abs(analytic) * 100.0
            print(f"PASS: tip displacement within {TOL*100:.0f}% (rel err {rel:.2f}%)")
            return 0
        rel = abs(abs(numeric) - abs(analytic)) / abs(analytic) * 100.0
        print(f"FAIL: tip displacement off by {rel:.2f}% (> {TOL*100:.0f}% tolerance)")
        return 1
    except subprocess.TimeoutExpired:
        print("NOTE=ccx solve exceeded the per-test timeout")
        print("FAIL: ccx timed out")
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc}")
        print("FAIL: calculix smoke test errored")
        return 1
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
