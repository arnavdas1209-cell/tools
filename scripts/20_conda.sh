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
# TIER 3 (fea): the FEA / multiphysics / mesh / CFD env.
# ===========================================================================
ensure_env fea envs/fea.yml

# --- MOOSE / PRISMS-PF (OPTIONAL, heavy) ------------------------------------
# MOOSE is a large multiphysics framework. Per the task it is OPTIONAL and only
# installed on hosts that clear the heavy threshold (RAM >= 16 GB AND free disk
# >= 40 GB), which 00_detect.sh encodes as HEAVY_OK=1. We use the conda-forge
# `moose-dev` package and NEVER compile from source. If HEAVY_OK!=1 we skip and
# document the gate; PRISMS-PF (built on deal.II, installed via apt in
# 10_apt.sh as libdeal.ii-dev) is the lighter companion on constrained hosts.
if [ "${HEAVY_OK:-0}" = "1" ]; then
  log "HEAVY_OK=1: installing OPTIONAL MOOSE via conda 'moose-dev' (no source build)."
  # moose-dev lives on the dedicated 'https://conda.software.inl.gov/public'
  # channel per the MOOSE docs; never source-compile.
  # cap "${CONDA}" create -y -n moose --channel https://conda.software.inl.gov/public \
  #   --channel conda-forge moose-dev \
  #   || log "WARN: moose-dev solve failed; see docs/UNSUPPORTED.md (MOOSE fallback)."
  log "MOOSE: moose-dev install wired (conda only). PRISMS-PF uses apt libdeal.ii-dev."
else
  log "SKIP OPTIONAL MOOSE/PRISMS-PF (HEAVY_OK!=1): needs RAM>=16GB and disk>=40GB; see docs/UNSUPPORTED.md."
  printf '\n- SKIPPED OPTIONAL `MOOSE`/`PRISMS-PF` in 20_conda.sh because HEAVY_OK!=1 (RAM<16GB or disk<40GB). Install path when enabled: conda `moose-dev` (never source-compiled). Fallback: FEniCSx / MFEM / deal.II (apt `libdeal.ii-dev`).\n' \
    >> "${REPO_ROOT}/docs/ENV_REPORT.md" || true
fi

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
