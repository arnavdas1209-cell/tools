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
# TODO(tier3-fea): FEA system deps (OpenFOAM apt repo gated by HEAVY_OK)
# ===========================================================================

# ===========================================================================
# TODO(tier4-cad): CAD/graphics system deps (inkscape, drawio deps, chromium)
# ===========================================================================

# ===========================================================================
# TODO(tier5-heavy): heavy system deps, gated by HEAVY_OK=1
# ===========================================================================

log "apt stage skeleton complete (no package lists yet)."
