# Scientific-Computing Workspace

A fully reproducible, **headless** (no GUI, no GPU), open-source engineering and
materials-science workspace: Ubuntu 24.04 devcontainer, per-domain conda-forge
environments, numbered install scripts, honest smoke tests, and GitHub Actions CI.

## Purpose

Give engineers and materials scientists a single reproducible workspace that
replaces common proprietary tools (Ansys/Abaqus/COMSOL, Fluent, SolidWorks,
ChemDraw, MATLAB/Simulink, Origin, Thermo-Calc, VASP, VESTA, LTspice, ...) with
open-source equivalents that run **headless** in a container or CI, with every
tool backed by a smoke test. The full proprietary -> open-source fallback map is
in [`docs/UNSUPPORTED.md`](UNSUPPORTED.md).

## Quick start

The two commands you need are **`make setup`** and **`make verify`**. Run them
inside the devcontainer (or any Ubuntu 24.04 host):

```bash
make setup    # detect environment, then run install stages 10..50 in order
make verify   # run every smoke test -> docs/VERIFY_REPORT.md
make report   # print docs/ENV_REPORT.md and docs/VERIFY_REPORT.md
make clean    # remove build artifacts (keeps source)
```

## Prerequisites

- **Ubuntu 24.04** (the devcontainer base). The install stages use `apt`,
  conda-forge, `npm`, and GitHub release binaries.
- **conda / mamba** (miniforge) for the per-domain environments in `envs/`.
- **Node.js + npm** for mermaid-cli, draw.io and the self-hosted Ketcher build.
- Optionally a working **Apptainer** (preferred) or **Docker** runtime for the
  container-image tools (Code_Aster, OpenFOAM fallback).
- `make`, `bash`, `git`, and Python 3.11.

Everything is authored to run **inside the devcontainer/CI**; no host build
system is required. On other hosts the install stages detect missing tooling and
skip gracefully (see the honesty rule below).

## Open in a devcontainer / GitHub Codespaces

This repo ships a `.devcontainer/` (Ubuntu 24.04 `Dockerfile` +
`devcontainer.json`). Two ways to open it:

- **VS Code + Dev Containers:** open the folder and run
  *"Dev Containers: Reopen in Container"*. The container builds from
  `.devcontainer/Dockerfile`.
- **GitHub Codespaces:** click **Code -> Codespaces -> Create codespace**. The
  same devcontainer definition is used.

Once the container is up, run `make setup` then `make verify`.

## Layout

| Path | Purpose |
| --- | --- |
| `.devcontainer/` | Ubuntu 24.04 headless devcontainer (Dockerfile + devcontainer.json) |
| `envs/` | Per-domain conda-forge environment YAMLs (core, fea, atomistic, cad, chem) |
| `scripts/` | Numbered install stages (`00_detect` .. `50_docker_images`) + `90_verify` |
| `tests/smoke/` | One smoke test per tool (PASS/FAIL/SKIP, 120s timeout) |
| `templates/` | LaTeX block-notes template |
| `notes/` | latex / obsidian-vault / notebooks / quarto |
| `figures/` | tikz / python / mermaid / drawio outputs |
| `refs/` | BibTeX library |
| `docs/` | README, UNSUPPORTED, generated ENV_REPORT & VERIFY_REPORT |
| `.github/workflows/` | CI: tiers 1-3 on push, tiers 4-5 nightly |

## Headless diagram export

Several diagram tools are GUI apps driven from the CLI. On a headless host they
run under a virtual framebuffer (`xvfb`) or a `--no-sandbox` browser.

- **Mermaid** (`@mermaid-js/mermaid-cli`): `30_node.sh` writes
  `scripts/puppeteer-config.json` pointing puppeteer at the system Chromium with
  `--no-sandbox`. Render with:

  ```bash
  mmdc -p scripts/puppeteer-config.json -i diagram.mmd -o diagram.svg
  ```

- **draw.io** (`drawio-desktop`): the Electron CLI exporter must run under
  `xvfb-run` on a headless host. Export a diagram to PDF/SVG with:

  ```bash
  xvfb-run -a drawio --no-sandbox -x -f pdf -o out.pdf input.drawio
  ```

- **Inkscape**: `inkscape in.svg --export-type=pdf --export-filename=out.pdf`.

## Self-hosted Ketcher (chemical structure editor)

`scripts/30_node.sh` clones [epam/ketcher](https://github.com/epam/ketcher),
builds the backend-free standalone bundle, and copies it to
`.local/ketcher/`. It is a static site, so serve it with any static HTTP
server (no backend required for 2D structure drawing):

```bash
npx http-server .local/ketcher -p 8080
# then open http://localhost:8080/ in a browser
```

Any static server works equally well, e.g. `python3 -m http.server 8080 -d .local/ketcher`.
If the build fails or exceeds the 30-min cap it is recorded in
[`docs/UNSUPPORTED.md`](UNSUPPORTED.md) with the RDKit/Indigo fallback.

## Obsidian vault & plugins

Lab notes live in `notes/obsidian-vault/`. The recommended community plugins
(and how to enable them for a scientific workflow) are documented in
[`notes/obsidian-vault/PLUGINS.md`](../notes/obsidian-vault/PLUGINS.md).

## FEA / multiphysics / mesh / CFD (Tier 3)

The `fea` conda env (`envs/fea.yml`) provides FEniCSx (dolfinx), FiPy,
scikit-fem, SFEPy, MFEM, meshio, pygmsh, PyVista and SU2; NGSolve is installed
via `pip` in that env's `pip:` section. System solvers (`calculix-ccx`, `gmsh`,
`elmerfem-csc`, `freefem++`, `code-saturne`, `paraview-python`,
`libdeal.ii-dev`) come from apt in `scripts/10_apt.sh`.

### Offscreen rendering (PyVista / ParaView)

On a headless host there is no X server, so PyVista/ParaView render through
software (**OSMesa**) or **EGL** OpenGL. `scripts/10_apt.sh` installs
`libosmesa6` (OSMesa) plus the Mesa DRI/EGL/GLX libraries and exports the
offscreen environment variables:

```bash
export PYVISTA_OFF_SCREEN=true   # PyVista never opens a window
export PYOPENGL_PLATFORM=osmesa  # or 'egl' on EGL-capable hosts
export MPLCONFIGDIR=/tmp/mpl     # writable matplotlib cache (read-only $HOME)
```

Set these in your shell (CI and the devcontainer already export them) so PyVista
renders headless:

```bash
PYVISTA_OFF_SCREEN=true python my_pyvista_script.py
```

OSMesa is the software rasteriser (no GPU needed); EGL is the GPU/accelerated
offscreen path. Either works for the headless smoke tests.

### OpenFOAM: apt repo (primary) with Docker fallback

- **Primary:** `scripts/10_apt.sh` adds the official
  [openfoam.org](https://openfoam.org) apt repo and installs the latest
  `openfoam` package.
- **Fallback:** if that repo is unreachable, `scripts/50_docker_images.sh`
  pulls the `opencfd/openfoam-default` image (only when a Docker runtime is
  available, `HAS_DOCKER=1`). The failure is logged to `docs/ENV_REPORT.md`; we
  do not loop.

### Code_Aster via container (`scripts/run_aster.sh`)

Code_Aster ships as a container image (pulled by `scripts/50_docker_images.sh`,
Apptainer preferred, Docker fallback). Run a study headless with:

```bash
scripts/run_aster.sh path/to/study.export     # or a .comm (a minimal .export is synthesized)
```

If no working container runtime exists (`CONTAINER_RUNTIME=none`),
`run_aster.sh` exits 2 (SKIP) cleanly and the situation is recorded in
[`docs/UNSUPPORTED.md`](UNSUPPORTED.md).

### MOOSE / PRISMS-PF (optional, heavy)

MOOSE is optional and only installed when `HEAVY_OK=1` (RAM >= 16 GB and free
disk >= 40 GB). `scripts/20_conda.sh` uses the conda `moose-dev` package and
**never** compiles from source. PRISMS-PF builds on deal.II (apt
`libdeal.ii-dev`). SALOME is skipped by design; see
[`docs/UNSUPPORTED.md`](UNSUPPORTED.md) for the Gmsh + meshio + ParaView
fallback.

## CAD + dynamics (Tier 4)

The `cad` conda env (`envs/cad.yml`) provides the scriptable CAD kernels
**CadQuery** and **build123d** (installed via `pip` in the env's `pip:` section;
they pull the OCP OpenCascade wheels). **FreeCAD**'s headless console
`FreeCADCmd` comes from apt in `scripts/10_apt.sh` and is the box-to-STEP path.
Modeling/dynamics tooling: **OpenModelica** (`omc`) from its official apt repo,
**Julia** via `juliaup` (`scripts/40_binaries.sh`, 30-min cap), **MBDyn** and
**CAMotics** guarded by apt availability, and **PyChrono** best-effort from the
`projectchrono` conda channel (never source-built). Smoke tests:
`freecad_step.sh` (box + STEP), `cadquery_stl.py` (solid + STL), `openscad.sh`
(STL), `openmodelica.sh` (trivial model), `julia.sh` (trivial script).

## Circuits (Tier 6)

Circuit simulation + EDA comes from apt in `scripts/10_apt.sh`: **ngspice**
(SPICE engine, also the PySpice backend), **KiCad** (we use only the headless
`kicad-cli`), and **Qucs-S**. **Xyce** is best-effort via conda-forge in
`scripts/40_binaries.sh` (fallback: ngspice). **PySpice** (a Python SPICE
front-end) is added to the core env (`envs/core.yml`); it needs the apt-provided
ngspice shared library at runtime. LaTeX circuit drawing uses **CircuiTikZ**,
already loaded by `templates/block-notes.tex` and exercised by
`notes/latex/demo.tex`. Smoke tests: `ngspice.sh` (RC transient), `kicad.sh`
(`kicad-cli` version + minimal schematic SVG export), `schemdraw_rc.py` (RC
circuit to PNG).

## Honesty rule & how to read `VERIFY_REPORT.md`

A tool is never marked **PASS** until its smoke test actually passes. Anything
that cannot install in a headless Linux container is recorded in
[`docs/UNSUPPORTED.md`](UNSUPPORTED.md) with the reason and a fallback.

`make verify` writes [`docs/VERIFY_REPORT.md`](VERIFY_REPORT.md): a markdown
table with columns **tool | tier | version | PASS/FAIL/SKIP | seconds | note**,
rows sorted by tier. Read it as follows:

- **PASS** - the smoke test exited `0`: the tool is installed and its tiny real
  computation (or render) succeeded. The `version` and `note` columns show what
  actually ran.
- **SKIP** - the smoke test exited `2`: the tool is absent / not applicable in
  this environment. The `note` explains why and points to where it runs for
  real; every SKIP has a matching reason + fallback in
  [`docs/UNSUPPORTED.md`](UNSUPPORTED.md).
- **FAIL** - any other nonzero exit (including a 120s timeout): the tool was
  present but its check failed. The report never fabricates a PASS.

The committed report reflects the **last real run on the validation host**
(Amazon Linux 2023: no apt, no conda, no working container runtime). On that
host only the pip-installable, pure-Python tests execute; everything that needs
apt/conda/npm/a container is honestly **SKIP** and is staged to run in the
Ubuntu 24.04 devcontainer / GitHub Actions CI.

## Final summary: what installed vs what was skipped (and why)

The current host run is **10 PASS / 0 FAIL / 28 SKIP (38 tests)**. The table
below summarises each tool, distinguishing **host-executed** (ran for real here)
from **devcontainer/CI-staged** (SKIP here, runs for real in the container).

### Host-executed (PASS on this host via pip)

| Tool / test | Tier | What ran |
| --- | --- | --- |
| core-python (numpy/scipy/sympy/matplotlib/schemdraw) | 1 | integral/det/plot + schemdraw SVG |
| rdkit_indigo | 2 | RDKit + Indigo molecule render |
| pycalphad_phase | 2 | Al-Zn phase diagram |
| cantera_thermo | 2 | O2 Gibbs energy at 1000 K |
| meshio_convert | 3 | VTU <-> MSH round-trip |
| fenics_poisson (scikit-fem fallback) | 3 | Poisson solve, error < tol |
| ase_pymatgen | 5 | BCC Fe -> space group Im-3m (229) |
| orix_polefigure | 5 | (001) pole figure PNG |
| torch_mace (torch CPU) | 5 | CPU tensor op (mace-torch optional) |
| schemdraw_rc | 6 | RC circuit PNG |

### Devcontainer/CI-staged (SKIP here; runs for real in the container/CI)

| Tools | Tier | Why skipped on host | Where / how they run |
| --- | --- | --- | --- |
| latex, mermaid, graphviz, inkscape, drawio, octave, scilab, gnuplot, grace, openscad, veusz | 1 | no apt/npm on host | apt + `scripts/30_node.sh` in devcontainer/CI |
| openbabel | 2 | conda-forge only | `chem` env |
| calculix, elmer, freefem, su2, openfoam | 3 | apt/conda/container only | apt / conda / openfoam.org repo + Docker fallback |
| code_aster | 3 | no working container runtime | Apptainer/Docker image; `scripts/run_aster.sh` |
| Salome | 3 | skipped by design (GUI/CAE bundle) | Gmsh + meshio + ParaView + FreeCAD |
| freecad_step, cadquery_stl, openmodelica, julia | 4 | apt / system OpenGL / release binary | apt + `envs/cad.yml` + `scripts/40_binaries.sh` |
| CAMotics, MBDyn | 4 | apt availability-guarded | AppImage / PyChrono |
| quantum_espresso, lammps, gromacs, ovito_load | 5 | apt/conda / system OpenGL-Qt | apt + `envs/atomistic.yml` |
| GPAW, Neper | 5 | apt availability-guarded / conda-forge | conda-forge / source build |
| ngspice, kicad | 6 | apt only | apt in devcontainer/CI |
| Xyce | 6 | no wheel / apt pkg | conda-forge, else ngspice |

Full reasons and the proprietary -> open-source fallback map are in
[`docs/UNSUPPORTED.md`](UNSUPPORTED.md); live results are in
[`docs/VERIFY_REPORT.md`](VERIFY_REPORT.md).

## Environment detection

`scripts/00_detect.sh` measures CPU/RAM/disk and detects docker, apptainer,
sudo, conda and apt. It writes [`docs/ENV_REPORT.md`](ENV_REPORT.md) and a
sourceable `scripts/.env-detect`. Heavy items (MOOSE/PRISMS-PF, OpenFOAM,
Code_Aster, texlive-fonts-extra) are gated behind `HEAVY_OK=1`
(RAM >= 16 GB and free disk >= 40 GB).
