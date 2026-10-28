# Unsupported / Skipped Tools

Per the honesty rule, any tool that cannot install or pass its smoke test in the
headless Linux container is recorded here with the **reason** and a **fallback**.
Do not loop on failures: try one alternative (conda-forge -> pip -> Docker/Apptainer
image), then document it here and move on.

## Tier 1 (notes + diagrams + plotting)

On the authoring/validation host (Amazon Linux 2023: no apt, no conda, no npm),
only the pure-Python core stack can actually execute. Everything that needs
apt/node/binary installs is **SKIP here** and runs for real in the Ubuntu 24.04
devcontainer / GitHub Actions CI. These are not failures: the smoke tests emit
exit 2 (SKIP) with a NOTE, per the honesty rule.

| Tool | Tier | Reason skipped/failed (on host) | Fallback / where it runs | Final status |
| --- | --- | --- | --- | --- |
| latex (texlive/latexmk/biber) | 1 | No apt on Amazon Linux 2023; TeX Live not installed | apt in devcontainer/CI | SKIP (host) |
| mermaid (mermaid-cli) | 1 | No npm/node on host | `scripts/30_node.sh` in devcontainer/CI (puppeteer -> system chromium, --no-sandbox) | SKIP (host) |
| graphviz (dot) | 1 | No apt on host | apt `graphviz` in devcontainer/CI | SKIP (host) |
| inkscape | 1 | No apt on host | apt `inkscape` (headless) in devcontainer/CI | SKIP (host) |
| drawio (drawio-desktop) | 1 | No npm + no xvfb on host | `scripts/30_node.sh`; run under `xvfb-run` in devcontainer/CI | SKIP (host) |
| octave | 1 | No apt on host | apt `octave` in devcontainer/CI | SKIP (host) |
| scilab | 1 | No apt on host | apt `scilab` in devcontainer/CI | SKIP (host) |
| gnuplot | 1 | No apt on host | apt `gnuplot` in devcontainer/CI | SKIP (host) |
| grace (gracebat) | 1 | No apt on host | apt `grace` in devcontainer/CI | SKIP (host) |
| openscad | 1 | No apt on host | apt `openscad` in devcontainer/CI | SKIP (host) |
| veusz | 1 | Not importable on host (no apt/conda) | apt `veusz` / conda-forge in devcontainer/CI | SKIP (host) |
| typst | 1 | Release binary not installed on host | `scripts/40_binaries.sh` (GitHub release) in devcontainer/CI | staged (no host smoke) |
| quarto | 1 | Release tarball not installed on host | `scripts/40_binaries.sh` (GitHub release) in devcontainer/CI | staged (no host smoke) |

> `core-python` (numpy/scipy/sympy/matplotlib/schemdraw) is the one Tier 1 test
> that **actually PASSED** on this host via a throwaway `/tmp` venv.

> Status note: `scipy-stats-extras` is intentionally omitted from `envs/core.yml`
> because no such conda-forge package exists; `scipy.stats` already provides the
> extended statistics API, so no fallback is needed.

## Tier 2 (thermo / phase / chemistry)

On the validation host (Amazon Linux 2023: no apt, no conda, no npm, no working
container runtime), several Tier 2 tools **did install via PyPI wheels and their
smoke tests PASSED for real**: `rdkit`, `epam.indigo`, `pycalphad`, and
`cantera` (see `docs/VERIFY_REPORT.md`). The remainder need conda-forge, npm, or
a Fortran toolchain and are **SKIP here**, running for real in the Ubuntu 24.04
devcontainer / CI. These are not failures: the smoke tests emit exit 2 (SKIP)
with a NOTE, per the honesty rule.

| Tool | Tier | Reason skipped/failed (on host) | Fallback / where it runs | Final status |
| --- | --- | --- | --- | --- |
| openbabel (obabel) | 2 | No conda on host; `obabel` CLI absent (no PyPI CLI) | conda-forge `openbabel` in `chem` env; RDKit/Indigo for conversions | SKIP (host) |
| xtb | 2 | conda-forge only (no PyPI wheel) | conda-forge `xtb` in `chem` env; else upstream Docker image | SKIP (host) |
| pyscf | 2 | Not attempted on host (conda-forge path) | conda-forge `pyscf` in `chem` env (devcontainer/CI) | SKIP (host) |
| psi4 | 2 | conda-forge/`psi4` label package; not on host | conda-forge `psi4` (add `psi4` channel if needed) or psi4 Docker image | SKIP (host) |
| espei | 2 | Part of `chem` conda env; not solved on host | conda-forge `espei` in `chem` env (devcontainer/CI) | SKIP (host) |
| Ketcher (epam/ketcher) | 2 | No npm/node on host; cannot build static site | `scripts/30_node.sh` builds `.local/ketcher` in devcontainer/CI; serve with `npx http-server .local/ketcher -p 8080`. Programmatic fallback: RDKit / Indigo | not built (host) |
| OpenCalphad (source build) | 2 | No gfortran/make toolchain guaranteed on host | `scripts/40_binaries.sh` best-effort gfortran build (30-min cap) in devcontainer/CI. Fallback: **pycalphad + ESPEI** | not built (host) |

> `rdkit_indigo`, `pycalphad_phase`, and `cantera_thermo` are the Tier 2 tests
> that **actually PASSED** on this host via a throwaway `/tmp` venv, writing
> `figures/python/{rdkit_molecule.png, indigo_molecule.png,
> pycalphad_alzn_phase.png, ellingham.png}`.

### Proprietary-tool fallback mapping (open-source replacements)

| Proprietary tool | Open-source fallback(s) in this workspace |
| --- | --- |
| ChemDraw | RDKit, Indigo (epam.indigo), Ketcher (self-hosted structure editor) |
| Thermo-Calc / FactSage | pycalphad, ESPEI, OpenCalphad (best-effort source build) |
