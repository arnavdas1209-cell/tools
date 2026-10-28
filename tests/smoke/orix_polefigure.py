#!/usr/bin/env python3
"""orix_polefigure.py - Tier 5 smoke test: orix loads a symmetry + pole figure.

Loads a crystal point-group symmetry (Oh, m-3m - cubic), generates a small set
of orientations, and plots a (001) pole figure with orix, saving it to
figures/python/orix_polefigure.png. orix plots through matplotlib, so we force
the Agg backend and set a writable MPLCONFIGDIR (the host's /root/.config is
read-only).

orix (and its deps) install from PyPI, so this runs for real on the validation
host.

Named orix_polefigure.py (NOT orix.py) so it does not shadow the real `orix`
package via sys.path[0], per the repo naming convention.

Exit-code contract: 0 PASS, 2 SKIP (orix absent), other nonzero FAIL.
Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib.util
import os
import sys

TIER = 5

# orix -> matplotlib need a writable config dir and a non-interactive backend;
# set these BEFORE importing matplotlib/orix.
os.environ.setdefault("MPLCONFIGDIR", "/tmp/mpl")
os.environ.setdefault("MPLBACKEND", "Agg")


def main() -> int:
    print(f"TIER={TIER}")

    if importlib.util.find_spec("orix") is None:
        print("NOTE=orix absent; conda-forge/pip orix in the 'atomistic' env (envs/atomistic.yml)")
        print("SKIP: orix not importable")
        return 2

    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        import orix
        from orix.quaternion import Orientation
        from orix.quaternion.symmetry import Oh
        from orix.vector import Vector3d

        print(f"VERSION=orix={getattr(orix, '__version__', '?')}")

        out_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
            "figures",
            "python",
        )
        os.makedirs(out_dir, exist_ok=True)
        out_png = os.path.join(out_dir, "orix_polefigure.png")

        # Load the cubic m-3m (Oh) crystal point-group symmetry and build a
        # handful of random orientations under it.
        symmetry = Oh
        orientations = Orientation.random((50,))
        orientations.symmetry = symmetry

        # (001) pole figure: where the crystal [001] directions land on the
        # stereographic projection for these orientations.
        pole = Vector3d([0, 0, 1])
        directions = orientations * pole

        fig = directions.scatter(
            projection="stereographic",
            return_figure=True,
            s=10,
        )
        fig.suptitle(f"(001) pole figure - {symmetry.name} symmetry")
        fig.savefig(out_png, dpi=100, bbox_inches="tight")
        plt.close(fig)
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc}")
        print("FAIL: orix pole-figure render failed")
        return 1

    if os.path.exists(out_png) and os.path.getsize(out_png) > 0:
        print(f"NOTE=loaded Oh symmetry, plotted (001) pole figure -> figures/python/orix_polefigure.png ({os.path.getsize(out_png)} bytes)")
        print("PASS: orix loaded a symmetry and plotted a pole figure to PNG")
        return 0

    print("NOTE=orix produced empty/missing PNG")
    print("FAIL: orix pole-figure render failed")
    return 1


if __name__ == "__main__":
    sys.exit(main())
