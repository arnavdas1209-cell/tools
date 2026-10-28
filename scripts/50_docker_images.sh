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
# TODO(tier3-fea): OpenFOAM fallback image (only if native install fails)
# ===========================================================================

# ===========================================================================
# TODO(tier5-heavy): Code_Aster image, gated by HEAVY_OK=1
# ===========================================================================

log "container-image stage skeleton complete (no images wired yet)."
