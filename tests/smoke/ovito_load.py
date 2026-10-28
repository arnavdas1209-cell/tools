#!/usr/bin/env python3
"""ovito_load.py - Tier 5 smoke test: OVITO loads a LAMMPS dump headless.

Writes a tiny LAMMPS dump file (a few atoms in a box), imports it with the
OVITO Python module (ovito.io.import_file), and checks that the resulting
DataCollection reports the expected particle count. This exercises OVITO's
file pipeline headlessly (no GUI).

The OVITO Python module installs as a pip wheel ("ovito"), but its native
extension needs system OpenGL/Qt (libGL.so.1) to import. On a headless host
without those libs the import raises an ImportError; we treat that as an
environment SKIP (exit 2), not a build FAIL - it runs for real in the
devcontainer/CI where the GL/Qt libs are present.

Named ovito_load.py (NOT ovito.py) so it does not shadow the real `ovito`
package via sys.path[0], per the repo naming convention.

Exit-code contract: 0 PASS, 2 SKIP (ovito absent / native GL libs missing),
other nonzero FAIL. Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib.util
import os
import sys
import tempfile

TIER = 5

# OVITO is a Qt/GL app; force offscreen so any Qt init does not need a display.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

N_ATOMS = 4

DUMP = """ITEM: TIMESTEP
0
ITEM: NUMBER OF ATOMS
4
ITEM: BOX BOUNDS pp pp pp
0.0 10.0
0.0 10.0
0.0 10.0
ITEM: ATOMS id type x y z
1 1 1.0 1.0 1.0
2 1 2.0 2.0 2.0
3 1 3.0 3.0 3.0
4 1 4.0 4.0 4.0
"""


def main() -> int:
    print(f"TIER={TIER}")

    if importlib.util.find_spec("ovito") is None:
        print("NOTE=ovito absent; pip ovito in the 'atomistic' env (envs/atomistic.yml)")
        print("SKIP: ovito not importable")
        return 2

    # The native OVITO extension needs system OpenGL/Qt (libGL.so.1). Treat a
    # missing-shared-object import error as an environment SKIP, not a FAIL.
    try:
        import ovito
        from ovito.io import import_file

        print(f"VERSION=ovito={getattr(ovito, '__version__', '?')}")
    except ImportError as exc:  # noqa: BLE001
        msg = str(exc)
        if "libGL" in msg or "GLX" in msg or "Qt" in msg or "cannot open shared object" in msg or "libOpenGL" in msg:
            print(f"NOTE=ovito installed but native import needs system OpenGL/Qt (libGL): {msg}; apt libgl1-mesa-dri/libglu1-mesa + Qt in devcontainer/CI")
            print("SKIP: ovito native GL/Qt libs unavailable")
            return 2
        print(f"NOTE=ImportError: {msg}")
        print("FAIL: ovito import failed")
        return 1

    try:
        with tempfile.TemporaryDirectory() as work:
            dump_path = os.path.join(work, "atoms.dump")
            with open(dump_path, "w", encoding="utf-8") as fh:
                fh.write(DUMP)

            pipeline = import_file(dump_path)
            data = pipeline.compute()
            n = data.particles.count
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc}")
        print("FAIL: ovito dump load failed")
        return 1

    print(f"NOTE=OVITO loaded a LAMMPS dump headless; particle count={n} (expected {N_ATOMS})")
    if n == N_ATOMS:
        print("PASS: OVITO loaded a dump file headless")
        return 0

    print(f"FAIL: expected {N_ATOMS} particles, got {n}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
