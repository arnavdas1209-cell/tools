# Bundled open-licensed test data

## `alzn_mey.tdb` - Al-Zn CALPHAD thermodynamic database

Used by `tests/smoke/pycalphad_phase.py` to compute a binary Al-Zn phase diagram.

- **System:** Al-Zn binary (phases LIQUID, FCC_A1, HCP_A3).
- **Assessment source:** Sabine an Mey, "Reevaluation of the Al-Zn System",
  *Z. Metallkd.* **84** (1993) 451-455.
- **TDB file author:** T. Abe, K. Hashimoto, Y. Sawada - Particle Simulation and
  Thermodynamics Group, National Institute for Materials Science (NIMS),
  Tsukuba, Japan (2011).
- **Source / provenance:** distributed as an example database with the
  [pycalphad](https://github.com/pycalphad/pycalphad) project
  (`examples/alzn_mey.tdb`).
- **License:** pycalphad and its bundled example databases are released under the
  **MIT License** (open-source). The database header retains the original NIMS
  attribution ("Copyright (C) NIMS 2009") and bibliographic citation above.

This file is included unmodified so the pycalphad smoke test is fully
self-contained (no network access required at test time).
