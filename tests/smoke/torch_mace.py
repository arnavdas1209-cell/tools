#!/usr/bin/env python3
"""torch_mace.py - Tier 5 smoke test (OPTIONAL ML): torch CPU tensor op.

Validates the OPTIONAL machine-learning stack from envs/atomistic.yml. It
imports torch (CPU build), runs a trivial tensor operation on the CPU and
checks the result, then best-effort reports whether mace-torch (MACE
interatomic potentials, which depends on torch) is importable. torch is a large
CPU wheel pulled from the PyTorch CPU index; it installs for real on the
validation host, so this is a REAL PASS when torch is present.

This whole test is OPTIONAL: if torch is absent it SKIPs (exit 2) rather than
failing, because the ML stack is marked OPTIONAL in the env.

Named torch_mace.py (NOT torch.py / mace.py) so it does not shadow those
packages, per the repo naming convention.

Exit-code contract: 0 PASS, 2 SKIP (torch absent), other nonzero FAIL.
Prints TIER=/VERSION=/NOTE= lines for the verify report.
"""
import importlib.util
import sys

TIER = 5


def main() -> int:
    print(f"TIER={TIER}")

    if importlib.util.find_spec("torch") is None:
        print("NOTE=torch absent (OPTIONAL ML stack); pip torch (CPU index) in envs/atomistic.yml")
        print("SKIP: torch not importable (OPTIONAL)")
        return 2

    try:
        import torch

        print(f"VERSION=torch={getattr(torch, '__version__', '?')}")

        # Trivial CPU tensor op: elementwise add then sum.
        x = torch.ones(3) + torch.full((3,), 2.0)
        total = float(x.sum())  # expect (1+2)*3 = 9.0
    except Exception as exc:  # noqa: BLE001
        print(f"NOTE={type(exc).__name__}: {exc}")
        print("FAIL: torch CPU tensor op errored")
        return 1

    if abs(total - 9.0) > 1e-6:
        print(f"NOTE=torch tensor op gave {total}, expected 9.0")
        print("FAIL: torch CPU tensor op produced wrong result")
        return 1

    mace_state = "present" if importlib.util.find_spec("mace") is not None else "absent (OPTIONAL)"
    print(f"NOTE=torch CPU tensor op OK (sum={total}); mace-torch {mace_state}")
    print("PASS: torch CPU tensor op succeeded (OPTIONAL ML stack)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
