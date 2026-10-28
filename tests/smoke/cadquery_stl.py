#!/usr/bin/env python3
"""cadquery_stl.py - Tier 4 smoke test: CadQuery builds a solid and exports STL.

Builds a simple box with a through-hole using the CadQuery fluent API, exports
it to an STL file, and verifies the file is a non-empty, well-formed STL (the
ASCII variant starts with "solid"; the binary variant is >= 84 bytes with a
nonzero triangle count in its header). CadQuery installs from PyPI wheels
(pulling the OCP OpenCascade bindings), so this runs for real on the validation
host.

Named cadquery_stl.py (NOT cadquery.py) so it does not shadow the real
`cadquery` package via sys.path[0], per the repo naming convention.

Exit-code contract: 0 PASS, 2 SKIP (cadquery absent), other nonzero FAIL.
Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib.util
import os
import struct
import sys

TIER = 4


def _valid_stl(path: str) -> bool:
    """Accept both ASCII ('solid') and binary (header + triangle count) STL."""
    if os.path.getsize(path) == 0:
        return False
    with open(path, "rb") as fh:
        head = fh.read(5)
        if head == b"solid":
            return True
        # Binary STL: 80-byte header + uint32 triangle count.
        fh.seek(80)
        count_bytes = fh.read(4)
        if len(count_bytes) < 4:
            return False
        (n_tri,) = struct.unpack("<I", count_bytes)
        return n_tri > 0 and os.path.getsize(path) >= 84


def main() -> int:
    print(f"TIER={TIER}")

    if importlib.util.find_spec("cadquery") is None:
        print("NOTE=cadquery absent; pip cadquery in the 'cad' env (envs/cad.yml)")
        print("SKIP: cadquery not importable")
        return 2

    # CadQuery's OCP (OpenCascade) wheels need system OpenGL libs (libGL.so.1).
    # On a headless host without mesa/OpenGL those are absent -> treat the import
    # of the native extension as an environment SKIP, not a build FAIL. A genuine
    # build/export error below is still reported FAIL.
    try:
        import cadquery as cq

        print(f"VERSION=cadquery={getattr(cq, '__version__', '?')}")
    except ImportError as exc:  # noqa: BLE001
        msg = str(exc)
        if "libGL" in msg or "GLX" in msg or "OSMesa" in msg or "cannot open shared object" in msg:
            print(f"NOTE=cadquery installed but native OCP import needs system OpenGL (mesa libGL): {msg}; apt libgl1-mesa-dri/libglu1-mesa in devcontainer/CI")
            print("SKIP: cadquery OCP native libs unavailable (missing system OpenGL)")
            return 2
        print(f"NOTE=ImportError: {msg}")
        print("FAIL: cadquery import failed")
        return 1

    try:
        out_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
            "figures",
            "python",
        )
        os.makedirs(out_dir, exist_ok=True)
        out_stl = os.path.join(out_dir, "cadquery_box.stl")

        # A 20 x 20 x 10 box with a centered 5 mm through-hole.
        result = cq.Workplane("XY").box(20, 20, 10).faces(">Z").hole(5)

        # Sanity check the built solid before exporting.
        vol = result.val().Volume()
        if vol <= 0:
            print("NOTE=CadQuery produced a non-positive solid volume")
            print("FAIL: CadQuery build invalid")
            return 1

        cq.exporters.export(result, out_stl)
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc}")
        print("FAIL: CadQuery build/export errored")
        return 1

    if _valid_stl(out_stl):
        print(f"NOTE=exported STL ({os.path.getsize(out_stl)} bytes) -> figures/python/cadquery_box.stl")
        print("PASS: CadQuery built a solid and exported STL")
        return 0

    print("NOTE=STL file missing/empty/malformed")
    print("FAIL: CadQuery STL export invalid")
    return 1


if __name__ == "__main__":
    sys.exit(main())
