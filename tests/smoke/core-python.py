#!/usr/bin/env python3
"""Tier 1 core-env smoke test: numpy / scipy / sympy / matplotlib / schemdraw.

Exercises each library with a tiny real computation (and renders two figures to
figures/python/). Exit-code contract:
  0 -> PASS (all required imports + computations succeeded)
  2 -> SKIP (none of the core libraries are importable here)
  1 -> FAIL (a library imported but its trivial check failed)

Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib
import os
import sys

TIER = 1
REQUIRED = ["numpy", "scipy", "sympy", "matplotlib", "schemdraw"]


def main() -> int:
    print(f"TIER={TIER}")

    present = {}
    missing = []
    for name in REQUIRED:
        try:
            present[name] = importlib.import_module(name)
        except Exception:  # noqa: BLE001 - absence is expected on bare hosts
            missing.append(name)

    if not present:
        print("NOTE=core python libs absent on host; run in core conda env (devcontainer/CI)")
        print("SKIP: no core libraries importable")
        return 2

    versions = ", ".join(
        f"{n}={getattr(m, '__version__', '?')}" for n, m in present.items()
    )
    print(f"VERSION={versions}")

    if missing:
        # Partial environment: be honest and FAIL so it is not reported as PASS.
        print(f"NOTE=missing core libs: {', '.join(missing)}")
        print(f"FAIL: missing required core libraries: {', '.join(missing)}")
        return 1

    try:
        import numpy as np

        a = np.arange(6).reshape(2, 3)
        assert a.sum() == 15

        from scipy import linalg

        det = linalg.det(np.array([[1.0, 2.0], [3.0, 4.0]]))
        assert abs(det - (-2.0)) < 1e-9

        import sympy as sp

        x = sp.symbols("x")
        assert sp.integrate(2 * x, x) == x**2

        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        out_dir = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
            "figures",
            "python",
        )
        os.makedirs(out_dir, exist_ok=True)

        fig, ax = plt.subplots()
        ax.plot(np.linspace(0, 1, 10), np.linspace(0, 1, 10) ** 2)
        ax.set_title("smoke: y = x^2")
        fig.savefig(os.path.join(out_dir, "core_matplotlib.png"), dpi=72)
        plt.close(fig)

        import schemdraw
        import schemdraw.elements as elm

        d = schemdraw.Drawing(show=False)
        d += elm.Resistor().label("R")
        d += elm.Capacitor().label("C")
        d.save(os.path.join(out_dir, "core_schemdraw.svg"))
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc}")
        print("FAIL: core computation/render check failed")
        return 1

    print("PASS: numpy/scipy/sympy/matplotlib/schemdraw all OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
