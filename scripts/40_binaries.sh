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
install_typst || log "Continuing despite Typst install failure (logged)."

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
install_quarto || log "Continuing despite Quarto install failure (logged)."

# ===========================================================================
# TODO(tier5-heavy): static heavy solver binaries, gated by HEAVY_OK=1
# ===========================================================================

log "binaries stage complete (Typst + Quarto CLI into ${BIN_DIR})."
