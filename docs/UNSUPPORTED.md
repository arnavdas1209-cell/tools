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

## Tier 3 (FEA / multiphysics / mesh / CFD)

On the validation host (Amazon Linux 2023: no apt, no conda, no working
container runtime), the FEA solvers/meshers/CFD tools are apt/conda/container
based and are **SKIP here**, running for real in the Ubuntu 24.04 devcontainer /
CI. The pure-python pieces that pip-install (`meshio`, and a `scikit-fem`
Poisson fallback) **actually PASSED** (see `docs/VERIFY_REPORT.md`). These SKIPs
are not failures: the smoke tests emit exit 2 (SKIP) with a NOTE, per the
honesty rule.

| Tool | Tier | Reason skipped/failed (on host) | Fallback / where it runs | Final status |
| --- | --- | --- | --- | --- |
| CalculiX (ccx) | 3 | `ccx` solver is apt-only (`calculix-ccx`); absent on host. The `gmsh` wheel can mesh, but without ccx the solve cannot run | apt `calculix-ccx` + `gmsh` in devcontainer/CI. The analytic cantilever check (delta=F*L^3/(3*E*I), 5% tol) is code-reviewable now | SKIP (host) |
| Elmer (ElmerSolver/ElmerGrid) | 3 | apt-only (`elmerfem-csc`); absent on host | apt `elmerfem-csc` in devcontainer/CI | SKIP (host) |
| FEniCSx (dolfinx) | 3 | conda-forge only for a working MPI/PETSc build; absent on host | conda-forge `fenics-dolfinx` in `fea` env; `dolfinx/dolfinx` Docker image. Host ran the **scikit-fem** Poisson fallback (PASS) | SKIP (dolfinx) / PASS (skfem) |
| FreeFEM (FreeFem++) | 3 | apt-only (`freefem++`); absent on host | apt `freefem++` in devcontainer/CI | SKIP (host) |
| OpenFOAM | 3 | No apt on host; openfoam.org repo + Docker both unavailable here | **Primary:** openfoam.org apt repo (`openfoam` pkg) in `scripts/10_apt.sh`. **Fallback:** `opencfd/openfoam-default` Docker image in `scripts/50_docker_images.sh` (gated on `HAS_DOCKER`) | SKIP (host) |
| SU2 (SU2_CFD) | 3 | conda-forge `su2` in `fea` env; absent on host | conda-forge `su2` in `fea` env, else SU2 release binaries / Docker image | SKIP (host) |
| Code_Aster | 3 | Ships as a container; host has **no working container runtime** (podman shim broken, apptainer absent -> `CONTAINER_RUNTIME=none`) | Official Code_Aster image via **Apptainer (preferred) or Docker**, pulled in `scripts/50_docker_images.sh`; run headless with `scripts/run_aster.sh <case.comm|.export>`. `run_aster.sh` exits 2 (SKIP) cleanly when no runtime exists | SKIP (host) |
| MOOSE / PRISMS-PF | 3 | OPTIONAL, heavy; conda-only `moose-dev`. Gated on `HEAVY_OK` (RAM>=16GB && disk>=40GB). No conda on host | conda `moose-dev` (channel `conda.software.inl.gov/public`) in `scripts/20_conda.sh`; **never source-compiled**. PRISMS-PF via deal.II (apt `libdeal.ii-dev`). Fallback: FEniCSx / MFEM | SKIP (host) |
| Salome (SALOME platform) | 3 | **Skipped by design.** Heavy GUI/CAD-CAE integration platform; no clean headless apt/conda install, and the official distribution is a large GUI bundle | **Fallback:** Gmsh (meshing) + meshio (mesh I/O) + ParaView/`paraview-python` (post) cover the headless mesh+visualize workflow; FreeCAD (Tier 4 CAD env) for CAD. Use the SALOME Docker image only if a GUI session is explicitly needed | SKIP (by design) |

> `meshio_convert` and `fenics_poisson` (via the scikit-fem fallback) are the
> Tier 3 tests that **actually PASSED** on this host via a throwaway `/tmp`
> venv. Everything requiring apt/conda/a container runtime is SKIP here and
> staged for the devcontainer/CI.

> **OpenFOAM paths, explicitly:** the primary install is the official
> openfoam.org apt repo added in `scripts/10_apt.sh` (install the latest
> `openfoam` metapackage). If that repo is unreachable we do NOT loop - we log
> it to `docs/ENV_REPORT.md` and fall back to the `opencfd/openfoam-default`
> Docker image pulled in `scripts/50_docker_images.sh` (only when
> `HAS_DOCKER=1`). The `openfoam` smoke test uses whichever is present and
> SKIPs when neither is.

> **Offscreen rendering:** `scripts/10_apt.sh` installs `libosmesa6` (+ EGL/GLX
> Mesa libs) and exports `PYVISTA_OFF_SCREEN=true` so PyVista/ParaView render
> headless with no X server. Documented in `docs/README.md`.

### Proprietary-tool fallback mapping (open-source replacements)

| Proprietary tool | Open-source fallback(s) in this workspace |
| --- | --- |
| ChemDraw | RDKit, Indigo (epam.indigo), Ketcher (self-hosted structure editor) |
| Thermo-Calc / FactSage | pycalphad, ESPEI, OpenCalphad (best-effort source build) |
| Ansys / Abaqus / COMSOL (FEA / multiphysics) | CalculiX, Code_Aster, Elmer, FEniCSx (also MFEM, deal.II/PRISMS-PF, MOOSE) |
| Ansys Fluent / CFX (CFD) | OpenFOAM, SU2 (also code-saturne) |
| SALOME (pre/post + CAE integration) | Gmsh + meshio + ParaView (paraview-python); FreeCAD for CAD |
