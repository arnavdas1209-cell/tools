#!/usr/bin/env bash
#
# 10_apt.sh - System package installation via apt (Ubuntu 24.04 devcontainer).
#
# AUTHORED FOR the Ubuntu 24.04 devcontainer. On non-apt hosts (e.g. Amazon
# Linux) this stage detects the missing apt and exits 0 after logging a skip,
# so `make setup` does not abort on hosts used only for authoring/validation.
#
# Tier package lists are intentionally NOT filled in here - they are added by
# later tier features in the clearly-marked TODO sections below.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_ROOT}/docs"
LOG_FILE="${LOG_DIR}/install-apt.log"
mkdir -p "${LOG_DIR}"

# --- logging helper ---------------------------------------------------------
log() { printf '[%s] [10_apt] %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "${LOG_FILE}"; }

# --- 30-min per-install cap helper ------------------------------------------
# Usage: cap <cmd> [args...]   # kills the command after 1800s.
cap() { timeout --kill-after=30s 1800 "$@"; }

# --- sudo helper (apt usually needs root; never used inside conda envs) ------
SUDO=""
[ "${HAS_SUDO:-0}" = "1" ] && [ "$(id -u)" -ne 0 ] && SUDO="sudo"

# --- source detection results -----------------------------------------------
ENV_DETECT="${SCRIPT_DIR}/.env-detect"
if [ -f "${ENV_DETECT}" ]; then
  # shellcheck source=/dev/null
  . "${ENV_DETECT}"
else
  log "WARN: ${ENV_DETECT} not found; run scripts/00_detect.sh first. Continuing with defaults."
fi

# --- guard: apt must be present ---------------------------------------------
if [ "${HAS_APT:-0}" != "1" ]; then
  log "SKIP: apt not available on this host; apt stage is authored for the Ubuntu 24.04 devcontainer."
  exit 0
fi

log "Starting apt stage. HEAVY_OK=${HEAVY_OK:-0}"

# Keep noninteractive so CI never blocks on prompts.
export DEBIAN_FRONTEND=noninteractive

# --- refresh indexes --------------------------------------------------------
cap ${SUDO} apt-get update

# --- apt install helper (noninteractive, capped) ----------------------------
# Usage: apt_install <pkg> [pkg...]
apt_install() {
  log "apt-get install: $*"
  cap ${SUDO} apt-get install -y --no-install-recommends "$@"
}

# ===========================================================================
# TIER 1 (core): notes + diagrams + plotting.
#   LaTeX stack (latex-extra/science/pictures/publishers/bibtex-extra + tools),
#   pandoc/imagemagick/ghostscript/librsvg, graph & plotting tools, vector/CAD
#   editors, numeric shells (octave/scilab), and the headless browser stack
#   (chromium + xvfb) used by mermaid-cli and drawio-desktop CLI export.
# ===========================================================================
log "TIER 1 apt packages (notes + diagrams + plotting)."
apt_install \
  texlive-latex-extra \
  texlive-science \
  texlive-pictures \
  texlive-publishers \
  texlive-bibtex-extra \
  latexmk \
  biber \
  chktex \
  pandoc \
  imagemagick \
  ghostscript \
  librsvg2-bin \
  graphviz \
  gnuplot \
  grace \
  veusz \
  inkscape \
  openscad \
  octave \
  scilab \
  chromium \
  xvfb

# texlive-fonts-extra is large (~1 GB+); gate it behind HEAVY_OK for portability
# on resource-constrained hosts. When skipped, note it in ENV_REPORT.md.
if [ "${HEAVY_OK:-0}" = "1" ]; then
  log "HEAVY_OK=1: installing texlive-fonts-extra."
  apt_install texlive-fonts-extra
else
  log "SKIP texlive-fonts-extra (HEAVY_OK!=1): low RAM/disk; see docs/ENV_REPORT.md."
  printf '\n- SKIPPED `texlive-fonts-extra` in 10_apt.sh because HEAVY_OK!=1 (RAM<16GB or disk<40GB). Fallback: core texlive fonts remain available; install manually if fonts are missing.\n' \
    >> "${REPO_ROOT}/docs/ENV_REPORT.md" || true
fi

# ===========================================================================
# TIER 3 (fea): FEA / multiphysics / mesh / CFD system packages.
#   Solvers/meshers/post from Ubuntu universe, plus headless offscreen GL
#   (OSMesa/EGL) for PyVista/ParaView, plus the official OpenFOAM apt repo.
# ===========================================================================
log "TIER 3 apt packages (FEA / multiphysics / mesh / CFD)."
apt_install \
  calculix-ccx \
  gmsh \
  elmerfem-csc \
  freefem++ \
  code-saturne \
  paraview-python \
  libdeal.ii-dev

# Offscreen rendering deps for PyVista / ParaView on a headless host (no X).
# libosmesa6 gives a software OpenGL context; the EGL/GLX libs cover GPU-less
# EGL rendering. PYVISTA_OFF_SCREEN=true (exported below) tells PyVista to use
# them instead of opening a window.
log "TIER 3 offscreen rendering deps (OSMesa / EGL)."
apt_install \
  libosmesa6 \
  libgl1-mesa-dri \
  libegl1 \
  xvfb

# Export PYVISTA_OFF_SCREEN so every PyVista/ParaView call in this shell renders
# headless. Documented in docs/README.md; smoke tests also set it defensively.
export PYVISTA_OFF_SCREEN=true
log "Exported PYVISTA_OFF_SCREEN=true for headless PyVista/ParaView rendering."

# --- OpenFOAM: official openfoam.org apt repo (primary path) ----------------
# Primary install path per the task: add the official openfoam.org apt repo and
# install the latest openfoam package. If the repo is unreachable (offline CI,
# air-gapped), we do NOT loop - we log it and rely on the Docker-image fallback
# pulled in scripts/50_docker_images.sh (gated on HAS_DOCKER). Both paths are
# documented in docs/README.md and docs/UNSUPPORTED.md.
log "OpenFOAM: attempting official openfoam.org apt repo (primary path)."
if curl -fsSL https://dl.openfoam.org/gpg.key 2>/dev/null \
      | ${SUDO} gpg --dearmor -o /usr/share/keyrings/openfoam-archive-keyring.gpg 2>/dev/null; then
  echo "deb [signed-by=/usr/share/keyrings/openfoam-archive-keyring.gpg] https://dl.openfoam.org/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-noble}") main" \
    | ${SUDO} tee /etc/apt/sources.list.d/openfoam.list >/dev/null
  if cap ${SUDO} apt-get update; then
    # The metapackage name tracks the latest release (e.g. openfoam12).
    if apt_install openfoam; then
      log "OpenFOAM installed from openfoam.org apt repo."
    else
      log "WARN: 'openfoam' metapackage not resolvable; falling back to Docker image (50_docker_images.sh)."
      printf '\n- OpenFOAM apt metapackage unresolvable from openfoam.org repo; Docker-image fallback (`scripts/50_docker_images.sh`, gated on HAS_DOCKER) applies. See docs/UNSUPPORTED.md.\n' \
        >> "${REPO_ROOT}/docs/ENV_REPORT.md" || true
    fi
  else
    log "WARN: openfoam.org repo index unreachable; using Docker-image fallback (50_docker_images.sh)."
  fi
else
  log "WARN: could not fetch openfoam.org GPG key (repo unreachable); using Docker-image fallback (50_docker_images.sh)."
  printf '\n- OpenFOAM openfoam.org apt repo unreachable (no GPG key); Docker-image fallback (`scripts/50_docker_images.sh`, gated on HAS_DOCKER) applies. See docs/UNSUPPORTED.md.\n' \
    >> "${REPO_ROOT}/docs/ENV_REPORT.md" || true
fi

# ===========================================================================
# TIER 4 (cad): CAD + dynamics system packages.
#   FreeCAD provides the headless console binary `FreeCADCmd`. CAMotics (G-code
#   simulator) and MBDyn (multibody dynamics) are only in some Ubuntu releases,
#   so they are guarded by availability (apt-cache policy) and documented in
#   docs/UNSUPPORTED.md when absent instead of aborting the stage. OpenModelica
#   comes from its own official apt repo.
# ===========================================================================
log "TIER 4 apt packages (CAD + dynamics)."

# FreeCAD: always attempt; FreeCADCmd is the headless console used by the smoke
# test (tests/smoke/freecad_step.sh).
apt_install freecad

# apt_available: true only if the package exists in the apt indexes.
# Usage: apt_available <pkg>
apt_available() {
  apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate:' \
    && ! apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate: (none)'
}

# document_unsupported <Tool> <reason> <fallback>
document_unsupported() {
  local tool="$1" reason="$2" fallback="$3"
  log "UNSUPPORTED: ${tool} - ${reason}"
  {
    echo ""
    echo "<!-- auto-appended by scripts/10_apt.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ) -->"
    echo "- **${tool}**: ${reason} Fallback: ${fallback}"
  } >> "${REPO_ROOT}/docs/UNSUPPORTED.md"
}

# CAMotics (G-code / CNC toolpath simulator) - guarded by availability.
if apt_available camotics; then
  apt_install camotics || document_unsupported "CAMotics" \
    "apt install failed on this host (devcontainer/CI)." \
    "CadQuery/build123d toolpaths; run the CAMotics AppImage from its GitHub releases."
else
  document_unsupported "CAMotics" \
    "not present in the apt indexes for this Ubuntu release." \
    "Install the official CAMotics AppImage from GitHub releases, or use CadQuery/build123d for CAM scripting."
fi

# MBDyn (multibody dynamics) - guarded by availability.
if apt_available mbdyn; then
  apt_install mbdyn || document_unsupported "MBDyn" \
    "apt install failed on this host (devcontainer/CI)." \
    "PyChrono (conda 'projectchrono' channel, see scripts/20_conda.sh) for multibody dynamics."
else
  document_unsupported "MBDyn" \
    "not present in the apt indexes for this Ubuntu release." \
    "PyChrono (conda 'projectchrono' channel, see scripts/20_conda.sh), or build MBDyn from source upstream."
fi

# OpenModelica: official apt repo (build.openmodelica.org). Add the signing key
# + source list, refresh, then install. If the repo is unreachable we do NOT
# loop - log it and document the OpenModelica Docker image fallback.
log "OpenModelica: attempting official build.openmodelica.org apt repo."
if curl -fsSL https://build.openmodelica.org/apt/openmodelica.asc 2>/dev/null \
      | ${SUDO} gpg --dearmor -o /usr/share/keyrings/openmodelica-keyring.gpg 2>/dev/null; then
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openmodelica-keyring.gpg] https://build.openmodelica.org/apt $(. /etc/os-release && echo "${UBUNTU_CODENAME:-noble}") release" \
    | ${SUDO} tee /etc/apt/sources.list.d/openmodelica.list >/dev/null
  if cap ${SUDO} apt-get update; then
    apt_install openmodelica || document_unsupported "OpenModelica" \
      "'openmodelica' package not resolvable from build.openmodelica.org." \
      "OpenModelica Docker image (openmodelica/openmodelica), or Julia/OpenModelica via the 'omc' binary release."
  else
    document_unsupported "OpenModelica" \
      "build.openmodelica.org apt index unreachable (offline/air-gapped)." \
      "OpenModelica Docker image (openmodelica/openmodelica)."
  fi
else
  document_unsupported "OpenModelica" \
    "could not fetch the build.openmodelica.org signing key (repo unreachable)." \
    "OpenModelica Docker image (openmodelica/openmodelica)."
fi

# ===========================================================================
# TIER 6 (circuits): circuit simulation + EDA system packages.
#   ngspice (SPICE engine; also the PySpice backend), KiCad (we only use the
#   headless `kicad-cli`), and Qucs-S (SPICE-based circuit simulator GUI with a
#   CLI). Xyce is handled in scripts/40_binaries.sh (conda/binary if available).
# ===========================================================================
log "TIER 6 apt packages (circuits / EDA)."
apt_install \
  ngspice \
  kicad \
  qucs-s

# ===========================================================================
# TODO(tier5-heavy): heavy system deps, gated by HEAVY_OK=1
# ===========================================================================

log "apt stage skeleton complete (no package lists yet)."
