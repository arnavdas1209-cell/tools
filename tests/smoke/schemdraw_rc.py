#!/usr/bin/env python3
"""schemdraw_rc.py - Tier 6 smoke test: schemdraw draws an RC circuit to PNG.

Builds a simple series RC circuit (source -> resistor -> capacitor -> ground)
with schemdraw and saves it to figures/python/schemdraw_rc.png. schemdraw
installs from PyPI (and conda-forge), so this runs for real on the validation
host. PNG output goes through matplotlib, so we force the Agg backend and set a
writable MPLCONFIGDIR (the host's /root/.config may be read-only).

Named schemdraw_rc.py (NOT schemdraw.py) so it does not shadow the real
`schemdraw` package via sys.path[0], per the repo naming convention.

Exit-code contract: 0 PASS, 2 SKIP (schemdraw absent), other nonzero FAIL.
Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib.util
import os
import sys

TIER = 6

# matplotlib/schemdraw need a writable config dir; the host's default may be
# read-only. Set these BEFORE importing matplotlib/schemdraw.
os.environ.setdefault("MPLCONFIGDIR", "/tmp/mpl")
os.environ.setdefault("MPLBACKEND", "Agg")


def main() -> int:
    print(f"TIER={TIER}")

    if importlib.util.find_spec("schemdraw") is None:
        print("NOTE=schemdraw absent; conda-forge/pip schemdraw in the core env")
        print("SKIP: schemdraw not importable")
        return 2

    try:
        import matplotlib

        matplotlib.use("Agg")

        import schemdraw
        import schemdraw.elements as elm

        print(f"VERSION=schemdraw={getattr(schemdraw, '__version__', '?')}")

        out_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
            "figures",
            "python",
        )
        os.makedirs(out_dir, exist_ok=True)
        out_png = os.path.join(out_dir, "schemdraw_rc.png")

        # Series RC circuit: 1 V source -> R -> C -> back to source.
        with schemdraw.Drawing(show=False) as d:
            d += elm.SourceV().up().label("1V")
            d += elm.Resistor().right().label("R = 1k")
            d += elm.Capacitor().down().label("C = 1u")
            d += elm.Line().left()
        d.save(out_png)
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc}")
        print("FAIL: schemdraw RC render failed")
        return 1

    if os.path.exists(out_png) and os.path.getsize(out_png) > 0:
        print(f"NOTE=drew RC circuit -> figures/python/schemdraw_rc.png ({os.path.getsize(out_png)} bytes)")
        print("PASS: schemdraw drew an RC circuit to PNG")
        return 0

    print("NOTE=schemdraw produced empty/missing PNG")
    print("FAIL: schemdraw RC render failed")
    return 1


if __name__ == "__main__":
    sys.exit(main())
