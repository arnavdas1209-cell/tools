#!/usr/bin/env python3
"""rdkit_indigo.py - Tier 2 smoke test: render one molecule with RDKit + Indigo.

Renders the same molecule (aspirin SMILES) to a PNG with each cheminformatics
toolkit:
  - RDKit  -> figures/python/rdkit_molecule.png
  - Indigo (epam.indigo) -> figures/python/indigo_molecule.png

Named rdkit_indigo.py (NOT rdkit.py / indigo.py) so it does not shadow either
package via sys.path[0].

Exit-code contract:
  0 -> PASS (at least one toolkit rendered; any present toolkit that ERRORS -> FAIL)
  2 -> SKIP (neither RDKit nor Indigo importable)
  1 -> FAIL (a present toolkit failed to render)
Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib.util
import os
import sys

TIER = 2
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(REPO_ROOT, "figures", "python")
SMILES = "CC(=O)OC1=CC=CC=C1C(=O)O"  # aspirin (acetylsalicylic acid)


def _have(mod: str) -> bool:
    try:
        return importlib.util.find_spec(mod) is not None
    except (ImportError, ValueError):
        return False


def render_rdkit() -> str:
    import rdkit
    from rdkit import Chem
    from rdkit.Chem.Draw import rdMolDraw2D

    mol = Chem.MolFromSmiles(SMILES)
    if mol is None:
        raise RuntimeError("RDKit could not parse SMILES")
    drawer = rdMolDraw2D.MolDraw2DCairo(300, 300)
    drawer.DrawMolecule(mol)
    drawer.FinishDrawing()
    out = os.path.join(OUT_DIR, "rdkit_molecule.png")
    with open(out, "wb") as fh:
        fh.write(drawer.GetDrawingText())
    if not (os.path.isfile(out) and os.path.getsize(out) > 0):
        raise RuntimeError("RDKit produced an empty PNG")
    return f"rdkit={rdkit.__version__}"


def render_indigo() -> str:
    from indigo import Indigo
    from indigo.renderer import IndigoRenderer

    indigo = Indigo()
    renderer = IndigoRenderer(indigo)
    mol = indigo.loadMolecule(SMILES)
    mol.layout()
    indigo.setOption("render-output-format", "png")
    indigo.setOption("render-image-size", 300, 300)
    out = os.path.join(OUT_DIR, "indigo_molecule.png")
    renderer.renderToFile(mol, out)
    if not (os.path.isfile(out) and os.path.getsize(out) > 0):
        raise RuntimeError("Indigo produced an empty PNG")
    return f"indigo={indigo.version()}"


def main() -> int:
    print(f"TIER={TIER}")

    have_rdkit = _have("rdkit")
    have_indigo = _have("indigo")

    if not (have_rdkit or have_indigo):
        print("NOTE=rdkit/indigo absent; rdkit via pip or conda, indigo via pip (chem env)")
        print("SKIP: neither RDKit nor Indigo importable")
        return 2

    os.makedirs(OUT_DIR, exist_ok=True)
    versions = []
    rendered = 0

    for name, present, fn in (
        ("RDKit", have_rdkit, render_rdkit),
        ("Indigo", have_indigo, render_indigo),
    ):
        if not present:
            continue
        try:
            versions.append(fn())
            rendered += 1
        except Exception as exc:  # noqa: BLE001
            print(f"NOTE={name} failed: {type(exc).__name__}: {exc}")
            print(f"FAIL: {name} molecule render failed")
            return 1

    print(f"VERSION={', '.join(versions)}")
    print(f"PASS: rendered aspirin with {rendered} toolkit(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
