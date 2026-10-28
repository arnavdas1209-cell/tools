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

log "Starting binaries stage. Installing into ${BIN_DIR}. HEAVY_OK=${HEAVY_OK:-0}"

# Helper: download a URL to a destination under the 30-min cap.
# Usage: fetch <url> <dest>
fetch() {
  local url="$1" dest="$2"
  log "Fetching ${url} -> ${dest} (capped at 30 min)."
  # if command -v curl >/dev/null 2>&1; then
  #   cap curl -fsSL "${url}" -o "${dest}"
  # else
  #   cap wget -q "${url}" -O "${dest}"
  # fi
}

# ===========================================================================
# TODO(tier2-quarto): Quarto CLI release tarball -> ${BIN_DIR}
# ===========================================================================

# ===========================================================================
# TODO(tier4-cad): drawio-desktop AppImage (headless via xvfb) -> ${BIN_DIR}
# ===========================================================================

# ===========================================================================
# TODO(tier5-heavy): static heavy solver binaries, gated by HEAVY_OK=1
# ===========================================================================

log "binaries stage skeleton complete (no downloads wired yet)."
