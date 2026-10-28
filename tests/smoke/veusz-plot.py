#!/usr/bin/env python3
"""veusz-plot.py - Tier 1 smoke test: Veusz renders a trivial plot to PNG.

Veusz ships an embedding API (veusz.embed) that works headless. The file is
named veusz-plot.py (not veusz.py) so it does not shadow the real package.
Exit-code contract: 0 PASS, 2 SKIP (veusz absent), other nonzero FAIL.
"""
import importlib.util
import os
import sys

TIER = 1


def _real_veusz_present() -> bool:
    """True only if a genuine 'veusz' package (not this test) is importable."""
    try:
        spec = importlib.util.find_spec("veusz")
    except (ImportError, ValueError):
        return False
    if spec is None or spec.origin is None:
        return False
    # Reject a match that resolves to this tests/smoke directory.
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(os.path.abspath(spec.origin)) != here


def main() -> int:
    print(f"TIER={TIER}")

    if not _real_veusz_present():
        print("NOTE=veusz absent on host; apt veusz / conda-forge in devcontainer/CI")
        print("SKIP: veusz not importable")
        return 2

    try:
        import veusz  # noqa: F401
        import veusz.embed as ve

        print(f"VERSION=veusz={getattr(veusz, '__version__', '?')}")

        out_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
            "figures",
            "python",
        )
        os.makedirs(out_dir, exist_ok=True)
        out_png = os.path.join(out_dir, "veusz_smoke.png")

        embed = ve.Embedded(hidden=True)
        page = embed.Root.Add("page")
        graph = page.Add("graph")
        xy = graph.Add("xy")
        embed.SetData("x", [1, 2, 3])
        embed.SetData("y", [1, 4, 9])
        xy.xData.val = "x"
        xy.yData.val = "y"
        embed.Export(out_png)
        embed.Close()
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc} (needs offscreen/Qt platform)")
        print("FAIL: veusz render failed")
        return 1

    if os.path.getsize(out_png) > 0:
        print("PASS: veusz rendered PNG")
        return 0

    print("NOTE=veusz produced empty PNG")
    print("FAIL: veusz render failed")
    return 1


if __name__ == "__main__":
    sys.exit(main())
