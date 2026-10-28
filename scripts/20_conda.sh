#!/usr/bin/env bash
#
# 20_conda.sh - Per-domain conda-forge environment creation.
#
# Creates separate conda-forge envs (core, fea, atomistic, cad, chem) to avoid
# solver conflicts. AUTHORED to run where conda/mamba is available (devcontainer
# via miniforge). On hosts without conda this stage logs a skip and exits 0.
#
# Rule: never use sudo inside conda envs. Tier env YAMLs (envs/*.yml) and their
# package lists are added by later tier features.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_ROOT}/docs"
LOG_FILE="${LOG_DIR}/install-conda.log"
mkdir -p "${LOG_DIR}"

log() { printf '[%s] [20_conda] %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "${LOG_FILE}"; }
cap() { timeout --kill-after=30s 1800 "$@"; }

ENV_DETECT="${SCRIPT_DIR}/.env-detect"
if [ -f "${ENV_DETECT}" ]; then
  # shellcheck source=/dev/null
  . "${ENV_DETECT}"
else
  log "WARN: ${ENV_DETECT} not found; run scripts/00_detect.sh first. Continuing with defaults."
fi

if [ "${HAS_CONDA:-0}" != "1" ]; then
  log "SKIP: conda/mamba not available on this host; conda stage is authored for the devcontainer."
  exit 0
fi

CONDA="${CONDA_BIN:-conda}"
log "Starting conda stage using '${CONDA}'. HEAVY_OK=${HEAVY_OK:-0}"

# Helper to create/update an env from a YAML file if it exists.
# Usage: ensure_env <name> <envs/file.yml>
ensure_env() {
  local name="$1" file="$2"
  if [ ! -f "${REPO_ROOT}/${file}" ]; then
    log "SKIP: ${file} not present yet (added by a later tier feature)."
    return 0
  fi
  log "Creating/updating env '${name}' from ${file} (capped at 30 min)."
  # cap "${CONDA}" env create -y -f "${REPO_ROOT}/${file}" \
  #   || cap "${CONDA}" env update -f "${REPO_ROOT}/${file}"
}

# ===========================================================================
# TODO(tier1-core): ensure_env core envs/core.yml
# ===========================================================================

# ===========================================================================
# TODO(tier3-fea): ensure_env fea envs/fea.yml  (heavy items gated by HEAVY_OK)
# ===========================================================================

# ===========================================================================
# TODO(tier4-atomistic): ensure_env atomistic envs/atomistic.yml
# ===========================================================================

# ===========================================================================
# TODO(tier4-cad): ensure_env cad envs/cad.yml
# ===========================================================================

# ===========================================================================
# TODO(tier5-chem): ensure_env chem envs/chem.yml
# ===========================================================================

log "conda stage skeleton complete (no env YAMLs wired yet)."
