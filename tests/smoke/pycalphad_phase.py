#!/usr/bin/env python3
"""pycalphad_phase.py - Tier 2 smoke test: binary Al-Zn phase diagram.

Loads the bundled open-licensed Al-Zn TDB (tests/smoke/data/alzn_mey.tdb),
computes the binary phase diagram with pycalphad and saves it as a PNG under
figures/python/.

Named pycalphad_phase.py (NOT pycalphad.py) so it does not shadow the real
`pycalphad` package via sys.path[0].

Exit-code contract: 0 PASS, 2 SKIP (pycalphad absent), other nonzero FAIL.
Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib.util
import os
import sys

TIER = 2
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TDB_PATH = os.path.join(REPO_ROOT, "tests", "smoke", "data", "alzn_mey.tdb")
OUT_DIR = os.path.join(REPO_ROOT, "figures", "python")
OUT_PNG = os.path.join(OUT_DIR, "pycalphad_alzn_phase.png")


def main() -> int:
    print(f"TIER={TIER}")

    if importlib.util.find_spec("pycalphad") is None:
        print("NOTE=pycalphad absent on host; conda-forge `chem` env in devcontainer/CI")
        print("SKIP: pycalphad not importable")
        return 2

    if not os.path.isfile(TDB_PATH):
        print(f"NOTE=bundled TDB missing at {TDB_PATH}")
        print("FAIL: required TDB not found")
        return 1

    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        import pycalphad
        from pycalphad import Database, binplot, variables as v

        print(f"VERSION=pycalphad={getattr(pycalphad, '__version__', '?')}")

        dbf = Database(TDB_PATH)
        comps = ["AL", "ZN", "VA"]
        phases = ["LIQUID", "FCC_A1", "HCP_A3"]

        os.makedirs(OUT_DIR, exist_ok=True)
        fig = plt.figure(figsize=(6, 5))
        ax = fig.add_subplot(111)
        conditions = {
            v.X("ZN"): (0, 1, 0.02),
            v.T: (300, 1000, 10),
            v.P: 101325,
            v.N: 1,
        }
        binplot(dbf, comps, phases, conditions, plot_kwargs={"ax": ax})
        ax.set_title("Al-Zn binary phase diagram (alzn_mey.tdb)")
        fig.savefig(OUT_PNG, dpi=100, bbox_inches="tight")
        plt.close(fig)
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc}")
        print("FAIL: pycalphad phase-diagram computation failed")
        return 1

    if os.path.isfile(OUT_PNG) and os.path.getsize(OUT_PNG) > 0:
        print(f"PASS: pycalphad wrote {os.path.relpath(OUT_PNG, REPO_ROOT)}")
        return 0

    print("NOTE=pycalphad produced no/empty PNG")
    print("FAIL: pycalphad phase-diagram output missing")
    return 1


if __name__ == "__main__":
    sys.exit(main())
