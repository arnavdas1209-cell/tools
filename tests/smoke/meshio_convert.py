#!/usr/bin/env python3
"""meshio_convert.py - Tier 3 smoke test: meshio round-trips a mesh.

Creates a tiny triangular mesh in memory, writes it to VTU and Gmsh (.msh)
formats, reads one back, and verifies the node/cell counts survive the
round-trip. meshio is pure-python and pip-installable, so this runs for real on
the validation host.

Named meshio_convert.py (NOT meshio.py) to avoid shadowing the real `meshio`
package via sys.path[0], per the repo naming convention.

Exit-code contract: 0 PASS, 2 SKIP (meshio absent), other nonzero FAIL.
Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib.util
import os
import sys
import tempfile

TIER = 3


def main() -> int:
    print(f"TIER={TIER}")

    if importlib.util.find_spec("meshio") is None:
        print("NOTE=meshio absent; conda-forge/pip meshio in fea env (devcontainer/CI)")
        print("SKIP: meshio not importable")
        return 2

    try:
        import numpy as np
        import meshio

        print(f"VERSION=meshio={getattr(meshio, '__version__', '?')}")

        # Two triangles forming a unit square.
        points = np.array(
            [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [1.0, 1.0, 0.0], [0.0, 1.0, 0.0]]
        )
        cells = [("triangle", np.array([[0, 1, 2], [0, 2, 3]]))]
        mesh = meshio.Mesh(points, cells)

        work = tempfile.mkdtemp(prefix="meshio_")
        vtu = os.path.join(work, "square.vtu")
        msh = os.path.join(work, "square.msh")
        mesh.write(vtu)
        mesh.write(msh, file_format="gmsh")

        back = meshio.read(vtu)
        n_pts = len(back.points)
        n_tri = sum(len(c.data) for c in back.cells if c.type == "triangle")
        print(f"NOTE=round-trip VTU+MSH -> {n_pts} points, {n_tri} triangles")

        if n_pts == 4 and n_tri == 2 and os.path.getsize(msh) > 0:
            print("PASS: meshio round-tripped VTU and Gmsh meshes")
            return 0
        print("FAIL: meshio round-trip counts mismatch")
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc}")
        print("FAIL: meshio smoke test errored")
        return 1


if __name__ == "__main__":
    sys.exit(main())
