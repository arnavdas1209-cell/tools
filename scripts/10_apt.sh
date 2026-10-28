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

# --- refresh indexes (real work added by later features) --------------------
# cap ${SUDO} apt-get update

# ===========================================================================
# TODO(tier1-core): base apt deps - build-essential, git, curl, ca-certificates,
#   xvfb, libgl1, libosmesa6, fonts, etc. (added in the core tier feature)
# ===========================================================================

# ===========================================================================
# TODO(tier2-latex): texlive base + latexmk (texlive-fonts-extra only if HEAVY_OK=1)
# ===========================================================================

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
