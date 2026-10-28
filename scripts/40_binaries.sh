#!/usr/bin/env bash
#
# 40_binaries.sh - Standalone binary / release-tarball tools.
#
# For tools distributed as prebuilt binaries or release assets (e.g. Quarto,
# drawio-desktop AppImage, static solvers) rather than via apt/conda/npm.
# Never compiles from source unless explicitly stated by a later feature.
#
# Tier download lists are added by later tier features.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_ROOT}/docs"
LOG_FILE="${LOG_DIR}/install-binaries.log"
BIN_DIR="${REPO_ROOT}/.local/bin"
mkdir -p "${LOG_DIR}" "${BIN_DIR}"

log() { printf '[%s] [40_binaries] %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "${LOG_FILE}"; }
cap() { timeout --kill-after=30s 1800 "$@"; }

ENV_DETECT="${SCRIPT_DIR}/.env-detect"
if [ -f "${ENV_DETECT}" ]; then
  # shellcheck source=/dev/null
  . "${ENV_DETECT}"
else
  log "WARN: ${ENV_DETECT} not found; run scripts/00_detect.sh first. Continuing with defaults."
fi

# --- tier gating (CI job split: tiers 1-3 push, tiers 4-6 nightly) ----------
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/_tiers.sh"
[ -n "${TIERS:-}" ] && log "tier filter active: TIERS='${TIERS}' (only these tiers install)."

log "Starting binaries stage. Installing into ${BIN_DIR}. HEAVY_OK=${HEAVY_OK:-0}"

# Helper: download a URL to a destination under the 30-min cap.
# Usage: fetch <url> <dest>
fetch() {
  local url="$1" dest="$2"
  log "Fetching ${url} -> ${dest} (capped at 30 min)."
  if command -v curl >/dev/null 2>&1; then
    cap curl -fsSL "${url}" -o "${dest}"
  elif command -v wget >/dev/null 2>&1; then
    cap wget -q "${url}" -O "${dest}"
  else
    log "ERROR: neither curl nor wget available; cannot fetch ${url}."
    return 1
  fi
}

# Map uname -m to the arch token used by Typst/Quarto release assets.
ARCH_RAW="$(uname -m)"
case "${ARCH_RAW}" in
  x86_64|amd64) TYPST_ARCH="x86_64"; QUARTO_ARCH="amd64" ;;
  aarch64|arm64) TYPST_ARCH="aarch64"; QUARTO_ARCH="arm64" ;;
  *) TYPST_ARCH="x86_64"; QUARTO_ARCH="amd64"
     log "WARN: unknown arch ${ARCH_RAW}; defaulting to x86_64/amd64." ;;
esac

# ===========================================================================
# TIER 1: Typst (official release binary from GitHub)
#   Primary: pinned release tarball. Fallback: 'latest' redirect asset.
#   Static musl binary -> no system deps; extracted into ${BIN_DIR}.
# ===========================================================================
TYPST_VERSION="v0.12.0"
install_typst() {
  local tmp tarball url dir
  tmp="$(mktemp -d)"
  tarball="${tmp}/typst.tar.xz"
  dir="typst-${TYPST_ARCH}-unknown-linux-musl"

  url="https://github.com/typst/typst/releases/download/${TYPST_VERSION}/${dir}.tar.xz"
  if fetch "${url}" "${tarball}"; then
    tar -xJf "${tarball}" -C "${tmp}"
    install -m 0755 "${tmp}/${dir}/typst" "${BIN_DIR}/typst"
    rm -rf "${tmp}"
    log "Installed Typst ${TYPST_VERSION} -> ${BIN_DIR}/typst"
    return 0
  fi

  # Fallback: latest release asset.
  log "Primary Typst download failed; trying latest release."
  url="https://github.com/typst/typst/releases/latest/download/${dir}.tar.xz"
  if fetch "${url}" "${tarball}"; then
    tar -xJf "${tarball}" -C "${tmp}"
    install -m 0755 "${tmp}/${dir}/typst" "${BIN_DIR}/typst"
    rm -rf "${tmp}"
    log "Installed Typst (latest) -> ${BIN_DIR}/typst"
    return 0
  fi

  rm -rf "${tmp}"
  log "ERROR: Typst install failed (primary + fallback). See docs/UNSUPPORTED.md."
  return 1
}
if tier_enabled 1; then
  install_typst || log "Continuing despite Typst install failure (logged)."
else
  log "SKIP TIER 1 Typst (not in TIERS='${TIERS}')."
fi

# ===========================================================================
# TIER 1: Quarto CLI (official release tarball from GitHub)
#   Primary: pinned linux-<arch>.tar.gz. Fallback: 'latest' redirect asset.
#   Extracted under ${BIN_DIR%/bin}/quarto and symlinked into ${BIN_DIR}.
# ===========================================================================
QUARTO_VERSION="1.6.40"
install_quarto() {
  local tmp tarball url prefix
  tmp="$(mktemp -d)"
  tarball="${tmp}/quarto.tar.gz"
  prefix="${BIN_DIR%/bin}/quarto"
  mkdir -p "${prefix}"

  url="https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-${QUARTO_ARCH}.tar.gz"
  if fetch "${url}" "${tarball}"; then
    tar -xzf "${tarball}" -C "${prefix}" --strip-components=1
    ln -sf "${prefix}/bin/quarto" "${BIN_DIR}/quarto"
    rm -rf "${tmp}"
    log "Installed Quarto ${QUARTO_VERSION} -> ${BIN_DIR}/quarto"
    return 0
  fi

  # Fallback: latest release asset.
  log "Primary Quarto download failed; trying latest release."
  url="https://github.com/quarto-dev/quarto-cli/releases/latest/download/quarto-linux-${QUARTO_ARCH}.tar.gz"
  if fetch "${url}" "${tarball}"; then
    tar -xzf "${tarball}" -C "${prefix}" --strip-components=1
    ln -sf "${prefix}/bin/quarto" "${BIN_DIR}/quarto"
    rm -rf "${tmp}"
    log "Installed Quarto (latest) -> ${BIN_DIR}/quarto"
    return 0
  fi

  rm -rf "${tmp}"
  log "ERROR: Quarto install failed (primary + fallback). See docs/UNSUPPORTED.md."
  return 1
}
if tier_enabled 1; then
  install_quarto || log "Continuing despite Quarto install failure (logged)."
else
  log "SKIP TIER 1 Quarto (not in TIERS='${TIERS}')."
fi

# ===========================================================================
# TIER 2: OpenCalphad (best-effort build from source) - sundmanbo/opencalphad
#   This is the ONE explicitly-allowed source build. OpenCalphad is a Fortran
#   CALPHAD assessment engine built with gfortran + make. Capped at 30 min; on
#   failure we log to docs/UNSUPPORTED.md with the pycalphad/ESPEI fallback and
#   move on (do not loop). Never uses sudo.
# ===========================================================================
OPENCALPHAD_REPO="https://github.com/sundmanbo/opencalphad.git"
build_opencalphad() {
  log "TIER 2: best-effort OpenCalphad source build (gfortran, capped at 30 min)."

  if ! command -v git >/dev/null 2>&1; then
    log "ERROR: git not available; cannot clone OpenCalphad."
    return 1
  fi
  if ! command -v gfortran >/dev/null 2>&1; then
    log "ERROR: gfortran not available; OpenCalphad needs a Fortran toolchain."
    return 1
  fi
  if ! command -v make >/dev/null 2>&1; then
    log "ERROR: make not available; cannot build OpenCalphad."
    return 1
  fi

  local src="${REPO_ROOT}/.local/opencalphad-src"
  rm -rf "${src}"
  if ! cap git clone --depth 1 "${OPENCALPHAD_REPO}" "${src}"; then
    log "ERROR: OpenCalphad clone failed."
    return 1
  fi

  # The repository ships a Makefile; `make` yields the `oc` console binary.
  # Build directory layout varies; build wherever a Makefile is found.
  local builddir=""
  for d in "${src}" "${src}/OCSoftware" "${src}/src"; do
    if [ -f "${d}/Makefile" ] || [ -f "${d}/makefile" ]; then builddir="${d}"; break; fi
  done
  if [ -z "${builddir}" ]; then
    log "ERROR: no Makefile found in OpenCalphad checkout."
    return 1
  fi

  if ! ( cd "${builddir}" && cap make ); then
    log "ERROR: OpenCalphad 'make' failed."
    return 1
  fi

  # Install any produced console executable (commonly named oc / oc6 / linkoc).
  local found=""
  for name in oc oc6 linkoc opencalphad; do
    if [ -x "${builddir}/${name}" ]; then
      install -m 0755 "${builddir}/${name}" "${BIN_DIR}/${name}"
      found="${name}"; break
    fi
  done
  if [ -z "${found}" ]; then
    log "ERROR: OpenCalphad build produced no recognizable executable."
    return 1
  fi

  log "Installed OpenCalphad (${found}) -> ${BIN_DIR}/${found}"
  return 0
}

if tier_enabled 2; then
if ! build_opencalphad; then
  UNSUP="${REPO_ROOT}/docs/UNSUPPORTED.md"
  log "OpenCalphad build failed/capped; recording in ${UNSUP} and moving on."
  {
    echo ""
    echo "<!-- auto-appended by scripts/40_binaries.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ) -->"
    echo "- **OpenCalphad** (sundmanbo/opencalphad): source build failed or exceeded the"
    echo "  30-min cap on this host (needs gfortran + make). Fallback: use **pycalphad**"
    echo "  and **ESPEI** (both in \`envs/chem.yml\`) for CALPHAD phase-diagram work."
    echo "  Re-run \`scripts/40_binaries.sh\` in the devcontainer/CI where the Fortran"
    echo "  toolchain is present."
  } >> "${UNSUP}"
fi
else
  log "SKIP TIER 2 OpenCalphad source build (not in TIERS='${TIERS}')."
fi

# ===========================================================================
# TIER 4: Julia via juliaup (official installer).
#   juliaup is Julia's official version manager. The installer script is
#   fetched from https://install.julialang.org and run non-interactively
#   (-y) under the 30-min cap. It installs into ~/.juliaup and symlinks the
#   `julia`/`juliaup` launchers into ~/.juliaup/bin; we additionally symlink
#   `julia` into ${BIN_DIR} so it is on the workspace PATH. On failure we do
#   NOT loop - we log it and document the fallback (official release tarball).
# ===========================================================================
install_julia() {
  log "TIER 4: installing Julia via juliaup (official installer, capped at 30 min)."
  if ! command -v curl >/dev/null 2>&1; then
    log "ERROR: curl not available; cannot run the juliaup installer."
    return 1
  fi

  # The installer respects JULIAUP_HOME / defaults to ~/.juliaup. Run it with
  # --yes so it never prompts, and --default-channel release for a stable Julia.
  if cap sh -c 'curl -fsSL https://install.julialang.org | sh -s -- --yes --default-channel release'; then
    local juliaup_bin="${HOME}/.juliaup/bin"
    if [ -x "${juliaup_bin}/julia" ]; then
      ln -sf "${juliaup_bin}/julia" "${BIN_DIR}/julia"
      ln -sf "${juliaup_bin}/juliaup" "${BIN_DIR}/juliaup" 2>/dev/null || true
      log "Installed Julia via juliaup -> ${BIN_DIR}/julia"
      return 0
    fi
    log "WARN: juliaup installer ran but ${juliaup_bin}/julia not found."
    return 1
  fi
  log "ERROR: juliaup installer failed or exceeded the 30-min cap."
  return 1
}

if tier_enabled 4; then
if ! install_julia; then
  UNSUP="${REPO_ROOT}/docs/UNSUPPORTED.md"
  log "Julia (juliaup) install failed/capped; recording in ${UNSUP} and moving on."
  {
    echo ""
    echo "<!-- auto-appended by scripts/40_binaries.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ) -->"
    echo "- **Julia** (juliaup): official installer failed or exceeded the 30-min"
    echo "  cap on this host. Fallback: download the official Julia release tarball"
    echo "  from https://julialang.org/downloads/ and extract its \`bin/julia\`"
    echo "  onto PATH. Re-run \`scripts/40_binaries.sh\` in the devcontainer/CI."
  } >> "${UNSUP}"
fi
else
  log "SKIP TIER 4 Julia (not in TIERS='${TIERS}')."
fi

# ===========================================================================
# TIER 6: Xyce (Sandia's parallel SPICE engine).
#   Xyce is NOT on PyPI and has no official Ubuntu apt package. We try the
#   conda-forge `xyce` package first (when conda is present), then document the
#   official binary installer / source-build fallback if unavailable. We never
#   compile from source here (not an allowed source build), and we do not loop.
# ===========================================================================
install_xyce() {
  log "TIER 6: attempting Xyce via conda-forge (if conda is present)."
  local conda_bin="${CONDA_BIN:-conda}"
  if [ "${HAS_CONDA:-0}" = "1" ] && command -v "${conda_bin}" >/dev/null 2>&1; then
    if cap "${conda_bin}" create -y -n xyce -c conda-forge xyce; then
      log "Installed Xyce via conda-forge into env 'xyce'."
      return 0
    fi
    log "WARN: conda-forge 'xyce' solve failed."
    return 1
  fi
  log "conda not available; cannot install Xyce via conda-forge on this host."
  return 1
}

if tier_enabled 6; then
if ! install_xyce; then
  UNSUP="${REPO_ROOT}/docs/UNSUPPORTED.md"
  log "Xyce install unavailable here; recording in ${UNSUP} and moving on."
  {
    echo ""
    echo "<!-- auto-appended by scripts/40_binaries.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ) -->"
    echo "- **Xyce** (Sandia parallel SPICE): no PyPI wheel and no official apt"
    echo "  package. Primary path: conda-forge \`xyce\` (attempted in"
    echo "  \`scripts/40_binaries.sh\` when conda is present). Fallback: the"
    echo "  official Xyce binary installer from https://xyce.sandia.gov/ , or"
    echo "  **ngspice** (apt, \`scripts/10_apt.sh\`) as the drop-in SPICE engine."
  } >> "${UNSUP}"
fi
else
  log "SKIP TIER 6 Xyce (not in TIERS='${TIERS}')."
fi

# ===========================================================================
# TIER 5: headless microscopy / microstructure tools (best-effort CLI only).
#   Fiji/ImageJ (run with --headless), DREAM.3D (PipelineRunner), and a
#   Gwyddion headless check. Each is a prebuilt release archive (no source
#   build), fetched under the 30-min cap. On any failure we do NOT loop - we log
#   the fallback to docs/UNSUPPORTED.md and move on. We only ever drive these
#   headlessly (no GUI). Gwyddion itself is preferably installed via apt
#   (scripts/10_apt.sh); here we only verify/locate its batch entry point.
# ===========================================================================

# document_unsupported_bin <Tool> <reason-and-fallback lines...>
document_unsupported_bin() {
  local tool="$1"; shift
  local UNSUP="${REPO_ROOT}/docs/UNSUPPORTED.md"
  log "UNSUPPORTED: ${tool} - ${*}"
  {
    echo ""
    echo "<!-- auto-appended by scripts/40_binaries.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ) -->"
    echo "- **${tool}**: ${*}"
  } >> "${UNSUP}"
}

# --- Fiji / ImageJ (headless CLI) -------------------------------------------
# Fiji ships as a portable archive with an ImageJ-linux64 launcher that accepts
# --headless for batch macro runs. We fetch the official Fiji Life-Line archive
# and extract its launcher into ${BIN_DIR}; the smoke test (if present) runs it
# with --headless. No GUI is ever started.
install_fiji() {
  log "TIER 5: installing Fiji/ImageJ (headless) from the official archive (capped at 30 min)."
  local tmp zip dir launcher
  tmp="$(mktemp -d)"
  zip="${tmp}/fiji.zip"
  if ! fetch "https://downloads.imagej.net/fiji/latest/fiji-linux64.zip" "${zip}"; then
    rm -rf "${tmp}"; return 1
  fi
  if ! ( cd "${tmp}" && unzip -q "${zip}" ); then
    log "ERROR: could not unzip Fiji archive (is 'unzip' installed?)."
    rm -rf "${tmp}"; return 1
  fi
  dir="${REPO_ROOT}/.local/Fiji.app"
  rm -rf "${dir}"
  mv "${tmp}/Fiji.app" "${dir}" 2>/dev/null || { rm -rf "${tmp}"; return 1; }
  rm -rf "${tmp}"
  # The 64-bit headless launcher.
  launcher="${dir}/ImageJ-linux64"
  if [ -x "${launcher}" ]; then
    ln -sf "${launcher}" "${BIN_DIR}/ImageJ-linux64"
    log "Installed Fiji/ImageJ -> ${BIN_DIR}/ImageJ-linux64 (run with --headless)."
    return 0
  fi
  log "WARN: Fiji launcher ImageJ-linux64 not found after extraction."
  return 1
}
if tier_enabled 5; then
if ! install_fiji; then
  document_unsupported_bin "Fiji/ImageJ" \
    "headless archive install failed or exceeded the 30-min cap on this host (needs 'unzip' + network). Fallback: run ImageJ via the official Docker image (fiji/fiji) with --headless, or use scikit-image / pyGwy for Python image analysis. Re-run scripts/40_binaries.sh in the devcontainer/CI."
fi

# --- DREAM.3D (PipelineRunner, headless) ------------------------------------
# DREAM.3D / DREAM3D-NX ships as a prebuilt Linux archive containing the
# headless PipelineRunner CLI. We fetch the archive and symlink PipelineRunner
# into ${BIN_DIR}. The exact release URL changes per version, so this is
# best-effort via the GitHub releases 'latest' asset; on failure we document
# the fallback and move on.
install_dream3d() {
  log "TIER 5: installing DREAM.3D PipelineRunner (headless) - best-effort (capped at 30 min)."
  local tmp tarball dir runner
  tmp="$(mktemp -d)"
  tarball="${tmp}/dream3d.tar.gz"
  # BlueQuartzSoftware publishes Linux archives on GitHub releases.
  if ! fetch "https://github.com/BlueQuartzSoftware/DREAM3D/releases/latest/download/DREAM3D-latest-Linux-x86_64.tar.gz" "${tarball}"; then
    rm -rf "${tmp}"; return 1
  fi
  if ! ( cd "${tmp}" && tar -xzf "${tarball}" ); then
    rm -rf "${tmp}"; return 1
  fi
  dir="${REPO_ROOT}/.local/dream3d"
  rm -rf "${dir}"; mkdir -p "${dir}"
  # Flatten the single top-level extracted directory into ${dir}.
  cp -a "${tmp}"/*/. "${dir}/" 2>/dev/null || cp -a "${tmp}"/. "${dir}/"
  rm -rf "${tmp}"
  runner="$(ls "${dir}"/bin/PipelineRunner "${dir}"/PipelineRunner 2>/dev/null | head -n1 || true)"
  if [ -n "${runner}" ] && [ -x "${runner}" ]; then
    ln -sf "${runner}" "${BIN_DIR}/PipelineRunner"
    log "Installed DREAM.3D PipelineRunner -> ${BIN_DIR}/PipelineRunner."
    return 0
  fi
  log "WARN: DREAM.3D PipelineRunner not found after extraction."
  return 1
}
if ! install_dream3d; then
  document_unsupported_bin "DREAM.3D (PipelineRunner)" \
    "prebuilt-archive install failed or exceeded the 30-min cap on this host (release asset URL is version-specific / network-gated). Fallback: download the matching DREAM3D-NX Linux archive from github.com/BlueQuartzSoftware/DREAM3D releases and put its bin/PipelineRunner on PATH, or run the DREAM.3D Docker image. Re-run scripts/40_binaries.sh in the devcontainer/CI."
fi

# --- Gwyddion (headless batch) ----------------------------------------------
# Gwyddion is preferably installed via apt (scripts/10_apt.sh). Here we only
# locate its non-interactive entry point: `gwyddion-thumbnailer` / the Python
# `gwy` module cover headless SPM data processing (the main `gwyddion` binary is
# a GUI). If neither apt nor the tools are present, document the fallback.
if command -v gwyddion-thumbnailer >/dev/null 2>&1 || command -v gwyddion >/dev/null 2>&1; then
  log "Gwyddion present (apt). Headless batch via gwyddion-thumbnailer / the 'gwy' Python module."
else
  document_unsupported_bin "Gwyddion (headless)" \
    "not installed (apt gwyddion absent on this host). Fallback: apt 'gwyddion' in the devcontainer/CI (preferred), the Gwyddion Flatpak (net.gwyddion.Gwyddion), or scikit-image for Python SPM/AFM image analysis."
fi
else
  log "SKIP TIER 5 Fiji/DREAM.3D/Gwyddion (not in TIERS='${TIERS}')."
fi

# ===========================================================================
# TODO(tier5-heavy): static heavy solver binaries, gated by HEAVY_OK=1
#   (none required: the Tier 5 DFT/MD engines come from apt in 10_apt.sh.)
# ===========================================================================

log "binaries stage complete (tier-gated into ${BIN_DIR})."
