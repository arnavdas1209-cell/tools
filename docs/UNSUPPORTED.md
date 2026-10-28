# Unsupported / Skipped Tools

Per the honesty rule, any tool that cannot install or pass its smoke test in the
headless Linux container is recorded here with the **reason** and a **fallback**.
Do not loop on failures: try one alternative (conda-forge -> pip -> Docker/Apptainer
image), then document it here and move on.

## Proprietary -> open-source fallback mapping (complete)

This is the canonical mapping of proprietary engineering / materials-science
tools to the open-source replacements provided (or staged) in this workspace.
Per-tier reasons and host-vs-devcontainer status are in the tables further down.

| Proprietary tool | Open-source fallback(s) |
| --- | --- |
| Ansys / Abaqus / COMSOL | CalculiX, Code_Aster, Elmer, FEniCSx |
| Ansys Fluent | OpenFOAM, SU2 |
| SolidWorks / Fusion | FreeCAD, CadQuery |
| ChemDraw | RDKit, Indigo, Ketcher |
| MATLAB / Simulink | Octave, Scilab/Xcos, Julia, OpenModelica |
| Origin | matplotlib, Veusz, gnuplot |
| Thermo-Calc / FactSage | pycalphad, ESPEI, OpenCalphad |
| VASP | Quantum ESPRESSO, ABINIT, GPAW |
| VESTA | py3Dmol, OVITO, ASE |
| LTspice | ngspice, Xyce |

### Environment-specific skips (recorded during the tiers)

These are tools skipped on **this validation host** for environment reasons, with
the reason and the open-source fallback / where they run for real. Each has a
matching detailed row in the per-tier tables below.

| Tool | Tier | Reason skipped (host) | Fallback / where it runs |
| --- | --- | --- | --- |
| Salome | 3 | Skipped by design; heavy GUI/CAE bundle, no clean headless apt/conda install | Gmsh + meshio + ParaView (post) + FreeCAD (CAD) |
| Code_Aster | 3 | No working container runtime on host (podman/conmon broken, apptainer absent -> `CONTAINER_RUNTIME=none`) | Official image via Apptainer/Docker in devcontainer/CI; `scripts/run_aster.sh` exits 2 (SKIP) cleanly |
| CAMotics | 4 | Not in every Ubuntu apt index; guarded by availability | CAMotics AppImage, or CadQuery/build123d for CAM scripting |
| MBDyn | 4 | Not in every Ubuntu apt index; guarded by availability | PyChrono (conda `projectchrono`), or MBDyn source build |
| Neper | 5 | Not in every Ubuntu apt index; guarded by availability | Neper source build (GSL + nlopt + libscotch), or DAMASK grid generation |
| GPAW | 5 | apt availability-guarded / conda-forge only; absent on host | conda-forge `gpaw` in `atomistic` env, or pip `gpaw`; alt DFT: QE / ABINIT |
| Xyce | 6 | No PyPI wheel and no official apt package; conda-forge only (no conda on host) | conda-forge `xyce`, else Xyce binary installer, else ngspice |
| CadQuery | 4 | OCP (OpenCascade) native import needs system OpenGL (`libGL.so.1`); `dnf` read-only on host | apt `libgl1-mesa-dri`/`libglu1-mesa` in devcontainer/CI; then exports STL for real |
| OVITO | 5 | Native extension needs system OpenGL/Qt (`libGL.so.1`); `dnf` read-only on host | apt `libgl1-mesa-dri`/`libglu1-mesa` + Qt in devcontainer/CI; fallback ASE for structure IO |

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
| Code_Aster | 3 | Ships as a container; host has **no working container runtime** (podman shim broken, apptainer absent -> `CONTAINER_RUNTIME=none`). The smoke test also needs the python `gmsh` module to synthesize a grouped MED mesh (gmsh needs system libGLU, absent on host), so it SKIPs at mesh generation before any runtime is even attempted | The test meshes a tiny box with **gmsh** (named `FIX`/`LOAD`/`VOL` physical groups), writes a MED mesh, and passes it to `scripts/run_aster.sh <case.comm> <mesh.mmed>`, which adds the `mmed` unit to the synthesized `.export` so `LIRE_MAILLAGE` reads a real mesh. Runs for real where gmsh + the official Code_Aster image (**Apptainer** preferred, Docker fallback, pulled in `scripts/50_docker_images.sh`) are present (devcontainer/CI). `run_aster.sh` exits 2 (SKIP) cleanly when no runtime exists | SKIP (host) |
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

## Tier 4 (CAD + dynamics)

On the validation host (Amazon Linux 2023: no apt, no conda, and a locked-down
`dnf` that cannot write its logs so no system packages can be added), the
CAD/dynamics tools split three ways:

- **Julia** (via `juliaup`) **actually PASSED** on this host: the official
  `install.julialang.org` installer ran under the 30-min cap (network open) and
  installed Julia 1.13.3; `tests/smoke/julia.sh` ran a trivial script
  (`sum(1:10)==55`). See `docs/VERIFY_REPORT.md`.
- **CadQuery** installs from PyPI wheels here, but its native **OCP**
  (OpenCascade) extension needs system OpenGL (`libGL.so.1`), which is apt/dnf
  provided and **absent** on this host; `dnf` is read-only so it cannot be
  added. The smoke test therefore **SKIPs** (exit 2) with that reason, running
  for real in the devcontainer/CI where `libgl1-mesa-dri`/`libglu1-mesa` exist.
- The rest need apt/conda and are **SKIP here**, running for real in the Ubuntu
  24.04 devcontainer / CI. These SKIPs are not failures (exit 2 + NOTE).

| Tool | Tier | Reason skipped/failed (on host) | Fallback / where it runs | Final status |
| --- | --- | --- | --- | --- |
| FreeCAD (FreeCADCmd) | 4 | `FreeCADCmd` is apt-only (`freecad`); absent on host | apt `freecad` in devcontainer/CI; the smoke test builds a box and exports STEP headlessly | SKIP (host) |
| CadQuery | 4 | Installs from PyPI, but OCP native import needs system OpenGL (`libGL.so.1`); absent and un-installable (`dnf` read-only) on host | pip `cadquery` in the `cad` env (`envs/cad.yml`) + apt `libgl1-mesa-dri`/`libglu1-mesa` in devcontainer/CI; then it exports STL for real | SKIP (host) |
| build123d | 4 | Same OCP/OpenGL dependency as CadQuery | pip `build123d` in the `cad` env; covered by the CadQuery STL test in CI | SKIP (host) |
| OpenSCAD | 4/1 | `openscad` is apt-only; absent on host (Tier 1 test already exports STL) | apt `openscad` in devcontainer/CI (`tests/smoke/openscad.sh`) | SKIP (host) |
| OpenModelica (omc) | 4 | `omc` ships via the official build.openmodelica.org apt repo; absent on host | apt `openmodelica` (official repo added in `scripts/10_apt.sh`) in devcontainer/CI; fallback `openmodelica/openmodelica` Docker image | SKIP (host) |
| Julia (juliaup) | 4 | n/a - **PASSED on host** via the official juliaup installer | `scripts/40_binaries.sh` (juliaup, 30-min cap); fallback: official Julia release tarball from julialang.org | **PASS (host)** |
| CAMotics | 4 | Not present in the apt indexes for every Ubuntu release; guarded by availability in `scripts/10_apt.sh` | Official CAMotics AppImage from GitHub releases, or CadQuery/build123d for CAM scripting | SKIP / guarded |
| MBDyn | 4 | Not present in the apt indexes for every Ubuntu release; guarded by availability in `scripts/10_apt.sh` | PyChrono (conda `projectchrono` channel, `scripts/20_conda.sh`), or MBDyn source build upstream | SKIP / guarded |
| PyChrono | 4 | conda-only on the dedicated `projectchrono` channel; no conda on host | conda `projectchrono` channel (best-effort, `scripts/20_conda.sh`); never source-built here. Fallback: MBDyn (apt) | SKIP (host) |

> `julia` is the Tier 4 test that **actually PASSED** on this host (juliaup,
> network open). Everything else requires apt/conda/system OpenGL and is SKIP
> here, staged for the devcontainer/CI.

> **FreeCAD vs CadQuery/build123d:** `FreeCADCmd` (apt `freecad`) is the headless
> console that scripts a box + STEP export; the `cad` conda env
> (`envs/cad.yml`) provides the scriptable CadQuery + build123d kernels (pip,
> OCP wheels) that export STL. The two are complementary CAD paths.

## Tier 6 (circuits)

On the validation host the circuit/EDA engines are apt/conda-based and are
**SKIP here**, running for real in the Ubuntu 24.04 devcontainer / CI. The one
pure-Python piece, **schemdraw**, installs from PyPI and **actually PASSED**,
drawing an RC circuit to PNG. These SKIPs are not failures (exit 2 + NOTE).

| Tool | Tier | Reason skipped/failed (on host) | Fallback / where it runs | Final status |
| --- | --- | --- | --- | --- |
| ngspice | 6 | `ngspice` is apt-only; absent on host | apt `ngspice` in devcontainer/CI; the smoke test runs an RC transient. Also the PySpice backend engine | SKIP (host) |
| KiCad (kicad-cli) | 6 | `kicad-cli` is apt-only (`kicad`); absent on host. We use only the headless CLI, never the GUI | apt `kicad` in devcontainer/CI; the smoke test reports `kicad-cli version` and exports a minimal schematic to SVG | SKIP (host) |
| Qucs-S | 6 | apt-only (`qucs-s`); absent on host | apt `qucs-s` in devcontainer/CI; SPICE-based circuit simulation | SKIP (host) |
| schemdraw | 6 | n/a - **PASSED on host** (pip) | conda-forge/pip `schemdraw` in the core env; drew an RC circuit to `figures/python/schemdraw_rc.png` | **PASS (host)** |
| PySpice | 6 | Installs from pip/conda, but needs the **ngspice shared library** (apt-only) at runtime; absent on host | `pyspice` in `envs/core.yml` + apt `ngspice` (shared lib) in devcontainer/CI | SKIP (host) |
| Xyce | 6 | No PyPI wheel and no official apt package; conda-forge `xyce` only (no conda on host) | conda-forge `xyce` (attempted in `scripts/40_binaries.sh`), else official Xyce binary installer from xyce.sandia.gov, else **ngspice** as the drop-in SPICE engine | SKIP (host) |

> `schemdraw_rc` is the Tier 6 test that **actually PASSED** on this host (pip),
> writing `figures/python/schemdraw_rc.png`. Everything else needs apt/conda and
> is SKIP here, staged for the devcontainer/CI.

> **CircuiTikZ (LaTeX):** the `circuitikz` package is loaded by
> `templates/block-notes.tex` (Tier 1) and exercised by `notes/latex/demo.tex`
> (a series RC circuit), so no extra Tier 6 LaTeX work is needed; it builds with
> the Tier 1 `texlive-*` stack in the devcontainer/CI.

### Proprietary-tool fallback mapping (Tiers 4 & 6)

| Proprietary tool | Open-source fallback(s) in this workspace |
| --- | --- |
| SolidWorks / Autodesk Fusion / Fusion 360 (CAD) | FreeCAD (FreeCADCmd), CadQuery, build123d (also OpenSCAD) |
| MATLAB / Simulink (modeling + dynamics) | Octave, Scilab/Xcos, Julia, OpenModelica |
| ADAMS / RecurDyn (multibody dynamics) | PyChrono (Project Chrono), MBDyn |
| LTspice / PSpice (SPICE) | ngspice, Xyce (also PySpice as a Python front-end) |
| Altium / OrCAD (EDA / schematic + PCB) | KiCad (kicad-cli), Qucs-S |

## Tier 5 (atomistic / DFT / MD / microstructure)

On the validation host (Amazon Linux 2023: no apt, no conda, and a locked-down
`dnf` that cannot add system packages), the Tier 5 tools split three ways:

- **ASE + pymatgen + spglib** and **orix** install from PyPI wheels and
  **actually PASSED** on this host: `ase_pymatgen.py` built BCC Fe and pymatgen
  reported space group **Im-3m (No. 229)** - the correctness assertion;
  `orix_polefigure.py` loaded the cubic `m-3m` (Oh) symmetry and plotted a (001)
  pole figure to `figures/python/orix_polefigure.png`. See
  `docs/VERIFY_REPORT.md`.
- The **OPTIONAL ML stack**: `torch` (CPU wheel from the PyTorch CPU index)
  installed for real and `torch_mace.py` ran a CPU tensor op (**PASS**);
  `mace-torch` is OPTIONAL (absent here, documented).
- The heavy **DFT/MD engines** (Quantum ESPRESSO, LAMMPS, GROMACS, ABINIT,
  CP2K, SIESTA, GPAW), **Neper**, **OVITO** (needs system OpenGL/Qt), and the
  **Fiji/DREAM.3D/Gwyddion** imaging tools are apt/conda/system-GL/release-
  archive based and are **SKIP here**, running for real in the Ubuntu 24.04
  devcontainer / CI. These SKIPs are not failures (exit 2 + NOTE).

| Tool | Tier | Reason skipped/failed (on host) | Fallback / where it runs | Final status |
| --- | --- | --- | --- | --- |
| ASE + pymatgen + spglib | 5 | n/a - **PASSED on host** (pip) | conda/pip in the `atomistic` env (`envs/atomistic.yml`); BCC Fe -> Im-3m (229) | **PASS (host)** |
| orix | 5 | n/a - **PASSED on host** (pip) | conda-forge/pip `orix` in the `atomistic` env; wrote `figures/python/orix_polefigure.png` | **PASS (host)** |
| torch (CPU) / mace-torch | 5 (OPTIONAL) | torch **PASSED** (CPU wheel); mace-torch OPTIONAL/absent here | OPTIONAL ML in `envs/atomistic.yml` pip: (PyTorch CPU index); mace-torch depends on torch | **PASS (torch)** / SKIP (mace) |
| Quantum ESPRESSO (pw.x) | 5 | `pw.x` is apt-only (`quantum-espresso`) / conda-forge; absent on host. Also needs a Si pseudopotential at runtime | apt `quantum-espresso` in devcontainer/CI; the smoke test runs a tiny Si SCF (set `ESPRESSO_PSEUDO`). Alternative DFT: ABINIT / GPAW | SKIP (host) |
| LAMMPS (lmp) | 5 | `lmp` is apt-only (`lammps`) / conda-forge; absent on host | apt `lammps` in devcontainer/CI; the smoke test runs a 100-step LJ NVE melt | SKIP (host) |
| GROMACS (gmx) | 5 | `gmx` is apt-only (`gromacs`) / conda-forge; absent on host | apt `gromacs` in devcontainer/CI; the smoke test reports version + a core-tool self-check | SKIP (host) |
| ABINIT / CP2K / SIESTA | 5 | apt-only (`abinit`/`cp2k`/`siesta`) / conda-forge; absent on host | apt in devcontainer/CI; alternative DFT engines driven via ASE calculators | SKIP (host) |
| GPAW | 5 | apt (guarded by availability) / conda-forge; absent on host | conda-forge `gpaw` in the `atomistic` env, or `pip install gpaw` (needs libxc + BLAS); guarded in `scripts/10_apt.sh`. Alternative DFT: QE / ABINIT | SKIP / guarded |
| OVITO (Python module) | 5 | pip wheel installs, but the native extension needs system OpenGL/Qt (`libGL.so.1`); absent and un-installable (`dnf` read-only) on host | pip `ovito` in the `atomistic` env + apt `libgl1-mesa-dri`/`libglu1-mesa` + Qt in devcontainer/CI; the smoke test loads a LAMMPS dump headless. Fallback: ASE for structure IO | SKIP (host) |
| DAMASK (python) | 5 | pip `damask` installs, but the full DAMASK grid solver (`damask-grid`) needs PETSc (apt/spack); only the Python package is pip-installable | pip `damask` in the `atomistic` env (pip:); full solver via apt/spack or the DAMASK Docker image in devcontainer/CI | SKIP (solver) |
| pyxem / kikuchipy / matminer / mp-api / phonopy / py3Dmol | 5 | part of the `atomistic` conda env; not solved on host (no conda) | conda-forge in `envs/atomistic.yml` (devcontainer/CI). `mp-api` also needs an `MP_API_KEY` (network-gated) | SKIP (host) |
| Neper | 5 | not present in every Ubuntu release; guarded by availability in `scripts/10_apt.sh` | Build Neper from source (github.com/neperfepx/neper; GSL + nlopt + libscotch), or DAMASK grid generation for polycrystals | SKIP / guarded |
| Fiji / ImageJ | 5 | release archive; headless install needs `unzip` + network; absent on host | `scripts/40_binaries.sh` fetches the Fiji archive and runs `ImageJ-linux64 --headless`; or the `fiji/fiji` Docker image. Python fallback: scikit-image | SKIP (host) |
| DREAM.3D (PipelineRunner) | 5 | version-specific release archive; network-gated; absent on host | `scripts/40_binaries.sh` best-effort fetch of the BlueQuartzSoftware release, symlinking `PipelineRunner`; or the DREAM.3D Docker image | SKIP (host) |
| Gwyddion | 5 | apt-only (`gwyddion`); absent on host. The main binary is a GUI; headless via `gwyddion-thumbnailer` / the `gwy` module | apt `gwyddion` in devcontainer/CI (preferred), the Gwyddion Flatpak (`net.gwyddion.Gwyddion`), or scikit-image for SPM/AFM analysis | SKIP (host) |

> `ase_pymatgen`, `orix_polefigure`, and `torch_mace` are the Tier 5 tests that
> **actually PASSED** on this host via a throwaway `/tmp` venv. BCC Fe resolving
> to **Im-3m (229)** is the correctness check; the orix run wrote
> `figures/python/orix_polefigure.png`. Everything requiring apt/conda/system
> OpenGL/Qt or a release archive is SKIP here and staged for the devcontainer/CI.

> **DFT/MD engines vs the Python stack:** the heavy solvers (QE, LAMMPS,
> GROMACS, ABINIT, CP2K, SIESTA, GPAW) come from apt (`scripts/10_apt.sh`); the
> `atomistic` conda env (`envs/atomistic.yml`) provides the scriptable Python
> layer (ASE drives/analyses the engines; pymatgen/spglib/phonopy for
> crystallography; orix/pyxem/kikuchipy for microstructure/EBSD; DAMASK/OVITO
> for microstructure). The OPTIONAL ML stack (scikit-learn / torch CPU /
> mace-torch) lives in the env's pip: section.

### Proprietary-tool fallback mapping (Tier 5)

| Proprietary tool | Open-source fallback(s) in this workspace |
| --- | --- |
| VASP (DFT) | Quantum ESPRESSO, ABINIT, GPAW (also CP2K, SIESTA; driven via ASE) |
| VESTA (crystal visualization) | py3Dmol, OVITO, ASE (also pymatgen structure plotting) |
| Materials Studio (atomistic suite) | ASE + pymatgen + matminer + phonopy (crystallography/thermodynamics) |
| Gatan DigitalMicrograph / OIM (EBSD) | orix, pyxem, kikuchipy (also DREAM.3D for microstructure pipelines) |
| Simpleware / Avizo (image -> mesh) | Fiji/ImageJ, Gwyddion, DREAM.3D, scikit-image |
