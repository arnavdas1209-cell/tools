#!/usr/bin/env python3
"""ase_pymatgen.py - Tier 5 smoke test: ASE + pymatgen BCC Fe space group.

Builds a body-centered-cubic iron crystal with ASE (ase.build.bulk), converts
it to a pymatgen Structure, and determines its space group with spglib via
pymatgen's SpacegroupAnalyzer. The correctness assertion is that BCC Fe is
space group Im-3m, International number 229 - if the detected number is not
229 the test FAILS (not a silent pass).

ase, pymatgen and spglib all install from PyPI wheels, so this runs for real on
the validation host.

Named ase_pymatgen.py (it imports `ase`/`pymatgen`/`spglib`, not a module named
"ase_pymatgen"), so it does not shadow any real package.

Exit-code contract: 0 PASS, 2 SKIP (packages absent), other nonzero FAIL.
Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib.util
import sys

TIER = 5
EXPECTED_SG_NUMBER = 229
EXPECTED_SG_SYMBOL = "Im-3m"


def main() -> int:
    print(f"TIER={TIER}")

    missing = [m for m in ("ase", "pymatgen", "spglib") if importlib.util.find_spec(m) is None]
    if missing:
        print(f"NOTE={'/'.join(missing)} absent; conda/pip in the 'atomistic' env (envs/atomistic.yml)")
        print("SKIP: ase/pymatgen/spglib not importable")
        return 2

    try:
        import ase
        import spglib
        from ase.build import bulk
        from pymatgen.io.ase import AseAtomsAdaptor
        from pymatgen.symmetry.analyzer import SpacegroupAnalyzer

        print(f"VERSION=ase={getattr(ase, '__version__', '?')} spglib={getattr(spglib, '__version__', '?')}")

        # BCC iron, conventional cubic cell (a = 2.87 Angstrom, 2 atoms/cell).
        fe = bulk("Fe", "bcc", a=2.87, cubic=True)
        structure = AseAtomsAdaptor.get_structure(fe)

        sga = SpacegroupAnalyzer(structure, symprec=1e-3)
        sg_symbol = sga.get_space_group_symbol()
        sg_number = sga.get_space_group_number()
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc}")
        print("FAIL: ase/pymatgen BCC Fe space-group analysis errored")
        return 1

    print(f"NOTE=BCC Fe space group {sg_symbol} (No. {sg_number}); expected {EXPECTED_SG_SYMBOL} (229)")

    if sg_number == EXPECTED_SG_NUMBER:
        print("PASS: ASE built BCC Fe and pymatgen reported space group Im-3m (229)")
        return 0

    print(f"FAIL: expected space group {EXPECTED_SG_NUMBER}, got {sg_number}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
