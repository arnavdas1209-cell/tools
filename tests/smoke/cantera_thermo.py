#!/usr/bin/env python3
"""cantera_thermo.py - Tier 2 smoke test: Gibbs energy + Ellingham diagram.

Two parts:
  1. Compute a standard molar Gibbs free energy with Cantera (preferred) or the
     `thermo` library (fallback) - proving the thermochemistry stack works.
  2. Draw an Ellingham diagram (standard Gibbs energy of oxide formation vs
     temperature) from bundled open thermodynamic data and save it to
     figures/python/.

Open data: the delta-Gf(T) = a + b*T coefficients below are the standard
textbook linearizations of oxide-formation free energies (kJ per mol O2), e.g.
Gaskell, "Introduction to the Thermodynamics of Materials". They are public,
widely published constants used purely to render an illustrative diagram.

Exit-code contract: 0 PASS, 2 SKIP (no thermo backend), other nonzero FAIL.
Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib.util
import os
import sys

TIER = 2
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(REPO_ROOT, "figures", "python")
OUT_PNG = os.path.join(OUT_DIR, "ellingham.png")

# Open Ellingham data: delta-G_f = a + b*T (kJ/mol O2), valid ~298-2000 K.
# Reaction basis is per mole of O2 so slopes are directly comparable.
ELLINGHAM = {
    "2 Mg + O2 -> 2 MgO": (-1203.0, 0.216),
    "4/3 Al + O2 -> 2/3 Al2O3": (-1120.0, 0.213),
    "Si + O2 -> SiO2": (-907.0, 0.175),
    "2 Fe + O2 -> 2 FeO": (-520.0, 0.125),
    "2 C + O2 -> 2 CO": (-221.0, -0.179),
}


def _have(mod: str) -> bool:
    try:
        return importlib.util.find_spec(mod) is not None
    except (ImportError, ValueError):
        return False


def compute_gibbs() -> str:
    """Return a human-readable Gibbs-energy result, or raise on failure."""
    if _have("cantera"):
        import cantera as ct

        gas = ct.Solution("gri30.yaml")
        gas.TPX = 1000.0, ct.one_atm, "O2:1"
        g = gas.gibbs_mole  # J/kmol
        return f"cantera={ct.__version__}; O2 g(1000K)={g / 1e6:.1f} kJ/kmol"

    if _have("thermo"):
        from thermo import Chemical

        water = Chemical("water", T=298.15, P=101325)
        # Gibbs energy of formation (ideal gas) is an open tabulated property.
        gf = getattr(water, "Gfgm", None)
        import thermo

        return f"thermo={thermo.__version__}; water Gf(ig)={gf} J/mol"

    raise RuntimeError("no thermo backend")


def draw_ellingham() -> None:
    import numpy as np
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    os.makedirs(OUT_DIR, exist_ok=True)
    T = np.linspace(300, 2000, 50)
    fig, ax = plt.subplots(figsize=(7, 5))
    for label, (a, b) in ELLINGHAM.items():
        dG = a + b * T  # kJ/mol O2
        ax.plot(T, dG, label=label)
    ax.set_xlabel("Temperature (K)")
    ax.set_ylabel(r"$\Delta G^\circ$ (kJ / mol O$_2$)")
    ax.set_title("Ellingham diagram (open textbook data)")
    ax.legend(fontsize=8, loc="lower right")
    ax.grid(True, alpha=0.3)
    fig.savefig(OUT_PNG, dpi=100, bbox_inches="tight")
    plt.close(fig)


def main() -> int:
    print(f"TIER={TIER}")

    if not (_have("cantera") or _have("thermo")):
        print("NOTE=cantera/thermo absent on host; conda-forge `chem` env in devcontainer/CI")
        print("SKIP: no thermochemistry backend importable")
        return 2

    if not _have("matplotlib"):
        print("NOTE=matplotlib absent; needed for the Ellingham plot")
        print("SKIP: matplotlib not importable")
        return 2

    try:
        gibbs = compute_gibbs()
        print(f"VERSION={gibbs}")
        draw_ellingham()
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc}")
        print("FAIL: Gibbs-energy / Ellingham step failed")
        return 1

    if os.path.isfile(OUT_PNG) and os.path.getsize(OUT_PNG) > 0:
        print(f"PASS: computed Gibbs energy + wrote {os.path.relpath(OUT_PNG, REPO_ROOT)}")
        return 0

    print("NOTE=Ellingham PNG missing/empty")
    print("FAIL: Ellingham plot not written")
    return 1


if __name__ == "__main__":
    sys.exit(main())
