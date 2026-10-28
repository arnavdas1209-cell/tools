#!/usr/bin/env bash
#
# run_aster.sh - Headless Code_Aster run wrapper.
#
# Code_Aster ships as a container image (no clean headless apt/conda path), so
# this wrapper runs a given study inside that image using the container runtime
# detected by scripts/00_detect.sh (CONTAINER_RUNTIME: prefers Apptainer, falls
# back to Docker). The image is pulled by scripts/50_docker_images.sh.
#
# Usage:
#   scripts/run_aster.sh <case.export>
#   scripts/run_aster.sh <case.comm> [mesh.mmed]   # a minimal .export is synthesized
#
# Code_Aster drives a study from an .export file that references the .comm
# command file (and mesh/result units). If given a .comm directly we write a
# minimal .export next to it so a reviewer can run either artifact.
#
# Exit codes (honoring the repo smoke-test contract so callers can map cleanly):
#   0  success (study ran, as_run returned 0)
#   2  SKIP - no working container runtime OR image unavailable (host case:
#      podman shim broken + apptainer absent -> CONTAINER_RUNTIME=none)
#   other nonzero  FAIL (study ran but errored)
#
# When SKIPping, the reason is documented in docs/UNSUPPORTED.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() { printf '[run_aster] %s\n' "$*" >&2; }

# --- Code_Aster container image (kept in sync with 50_docker_images.sh) ------
ASTER_IMAGE="${ASTER_IMAGE:-quay.io/codeaster/codeaster:latest}"

# --- source detection results (CONTAINER_RUNTIME, APPTAINER_BIN, ...) --------
ENV_DETECT="${SCRIPT_DIR}/.env-detect"
if [ -f "${ENV_DETECT}" ]; then
  # shellcheck source=/dev/null
  . "${ENV_DETECT}"
fi
RUNTIME="${CONTAINER_RUNTIME:-none}"

# --- argument handling ------------------------------------------------------
if [ "$#" -lt 1 ]; then
  log "usage: run_aster.sh <case.export | case.comm> [mesh.mmed]"
  exit 64
fi

CASE="$1"
if [ ! -f "${CASE}" ]; then
  log "case file not found: ${CASE}"
  exit 66
fi

# --- SKIP cleanly when no working container runtime -------------------------
if [ "${RUNTIME}" = "none" ]; then
  log "SKIP: no working container runtime (CONTAINER_RUNTIME=none)."
  log "SKIP: Code_Aster needs Apptainer or Docker; see docs/UNSUPPORTED.md."
  exit 2
fi

# --- resolve the .export to hand to as_run ----------------------------------
CASE_DIR="$(cd "$(dirname "${CASE}")" && pwd)"
CASE_BASE="$(basename "${CASE}")"
EXPORT_FILE=""

case "${CASE_BASE}" in
  *.export)
    EXPORT_FILE="${CASE_BASE}"
    ;;
  *.comm)
    # Synthesize a minimal .export referencing this .comm (+ optional mesh).
    STEM="${CASE_BASE%.comm}"
    EXPORT_FILE="${STEM}.export"
    MESH_ARG="${2:-}"
    {
      echo "P actions make_etude"
      echo "P memory_limit 512"
      echo "P time_limit 120"
      echo "P version stable"
      echo "F comm ${CASE_BASE} D 1"
      if [ -n "${MESH_ARG}" ] && [ -f "${CASE_DIR}/$(basename "${MESH_ARG}")" ]; then
        echo "F mmed $(basename "${MESH_ARG}") D 20"
      fi
      echo "F mess ${STEM}.mess R 6"
      echo "F resu ${STEM}.resu R 8"
    } > "${CASE_DIR}/${EXPORT_FILE}"
    log "synthesized minimal export: ${CASE_DIR}/${EXPORT_FILE}"
    ;;
  *)
    log "unrecognized case type (expected .export or .comm): ${CASE_BASE}"
    exit 64
    ;;
esac

# --- run as_run inside the image, headless ----------------------------------
log "running Code_Aster via ${RUNTIME} on ${CASE_DIR}/${EXPORT_FILE}"
rc=0
case "${RUNTIME}" in
  docker)
    docker run --rm \
      -v "${CASE_DIR}:/work" -w /work \
      "${ASTER_IMAGE}" \
      as_run "${EXPORT_FILE}" || rc=$?
    ;;
  apptainer|singularity)
    RT_BIN="${APPTAINER_BIN:-${RUNTIME}}"
    "${RT_BIN}" exec \
      --bind "${CASE_DIR}:/work" --pwd /work \
      "docker://${ASTER_IMAGE}" \
      as_run "${EXPORT_FILE}" || rc=$?
    ;;
  *)
    log "SKIP: unknown runtime '${RUNTIME}'."
    exit 2
    ;;
esac

if [ "${rc}" -eq 0 ]; then
  log "Code_Aster study completed."
  exit 0
fi
log "Code_Aster study failed (as_run rc=${rc})."
exit "${rc}"
