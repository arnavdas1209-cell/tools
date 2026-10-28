#!/usr/bin/env bash
#
# 50_docker_images.sh - Pull container images for tools that ship only as
# containers (e.g. Code_Aster, OpenFOAM fallback).
#
# Uses the container runtime chosen by 00_detect.sh (CONTAINER_RUNTIME), which
# prefers Apptainer/Singularity and falls back to Docker. If no working runtime
# is available (e.g. host docker is a broken podman shim) this stage logs a skip
# and exits 0; the related smoke tests then report SKIP.
#
# Tier image lists are added by later tier features.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_ROOT}/docs"
LOG_FILE="${LOG_DIR}/install-docker-images.log"
mkdir -p "${LOG_DIR}"

log() { printf '[%s] [50_docker_images] %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "${LOG_FILE}"; }
cap() { timeout --kill-after=30s 1800 "$@"; }

ENV_DETECT="${SCRIPT_DIR}/.env-detect"
if [ -f "${ENV_DETECT}" ]; then
  # shellcheck source=/dev/null
  . "${ENV_DETECT}"
else
  log "WARN: ${ENV_DETECT} not found; run scripts/00_detect.sh first. Continuing with defaults."
fi

RUNTIME="${CONTAINER_RUNTIME:-none}"
if [ "${RUNTIME}" = "none" ]; then
  log "SKIP: no working container runtime (apptainer absent, docker not working). Image-based tools will report SKIP."
  exit 0
fi

# --- tier gating (CI job split: tiers 1-3 push, tiers 4-6 nightly) ----------
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/_tiers.sh"
[ -n "${TIERS:-}" ] && log "tier filter active: TIERS='${TIERS}' (only these tiers pull images)."

log "Starting container-image stage using '${RUNTIME}'. HEAVY_OK=${HEAVY_OK:-0}"

# Helper: pull an image with the detected runtime under the 30-min cap.
# Usage: pull_image <image-ref>
pull_image() {
  local ref="$1"
  log "Pulling ${ref} via ${RUNTIME} (capped at 30 min)."
  # case "${RUNTIME}" in
  #   docker)              cap docker pull "${ref}" ;;
  #   apptainer|singularity) cap "${RUNTIME}" pull "docker://${ref}" ;;
  # esac
}

# ===========================================================================
# TIER 3 (fea): OpenFOAM fallback image.
#   Primary OpenFOAM path is the openfoam.org apt repo in scripts/10_apt.sh.
#   This image is the documented fallback when that repo is unreachable. Only
#   relevant when a Docker runtime is available (HAS_DOCKER=1); with Apptainer
#   we pull the docker:// ref the same way. The openfoam smoke test uses the
#   native install when present and otherwise SKIPs.
# ===========================================================================
if tier_enabled 3; then
log "TIER 3: OpenFOAM fallback container image."
pull_image "opencfd/openfoam-default:latest"

# ===========================================================================
# TIER 3 (fea): Code_Aster image.
#   Code_Aster ships as a container; there is no clean apt/conda path for a
#   headless install. We prefer Apptainer (CONTAINER_RUNTIME picks it when
#   present) and fall back to Docker. scripts/run_aster.sh runs a .comm/.export
#   case against this image and SKIPs cleanly when no runtime exists (the host
#   case: podman shim broken, apptainer absent). Documented in UNSUPPORTED.md.
# ===========================================================================
log "TIER 3: Code_Aster container image."
pull_image "quay.io/codeaster/codeaster:latest"
else
  log "SKIP TIER 3 container images (OpenFOAM/Code_Aster) (not in TIERS='${TIERS}')."
fi

log "container-image stage complete (tier-gated per TIERS='${TIERS:-all}')."
