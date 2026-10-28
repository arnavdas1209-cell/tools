#!/usr/bin/env bash
#
# 30_node.sh - Node.js / npm global tooling (e.g. mermaid-cli, drawio export).
#
# AUTHORED to run where node + npm are available (devcontainer installs node).
# On hosts without npm this stage logs a skip and exits 0. Headless tools such
# as mermaid-cli are configured later to use system chromium with --no-sandbox.
#
# Tier package lists are added by later tier features.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_ROOT}/docs"
LOG_FILE="${LOG_DIR}/install-node.log"
mkdir -p "${LOG_DIR}"

log() { printf '[%s] [30_node] %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "${LOG_FILE}"; }
cap() { timeout --kill-after=30s 1800 "$@"; }

ENV_DETECT="${SCRIPT_DIR}/.env-detect"
if [ -f "${ENV_DETECT}" ]; then
  # shellcheck source=/dev/null
  . "${ENV_DETECT}"
else
  log "WARN: ${ENV_DETECT} not found; run scripts/00_detect.sh first. Continuing with defaults."
fi

if ! command -v npm >/dev/null 2>&1; then
  log "SKIP: npm not available on this host; node stage is authored for the devcontainer."
  exit 0
fi

log "Starting node stage. node=$(node --version 2>/dev/null || echo n/a) npm=$(npm --version 2>/dev/null || echo n/a)"

# Helper: install a global npm package under the 30-min cap.
# Usage: npm_global <pkg>[@version]
npm_global() {
  log "npm i -g $1 (capped at 30 min)."
  # cap npm install -g --no-fund --no-audit "$1"
}

# ===========================================================================
# TODO(tier4-figures): @mermaid-js/mermaid-cli  (puppeteer -> system chromium,
#   --no-sandbox; config written by the figures tier feature)
# ===========================================================================

# ===========================================================================
# TODO(tier4-figures): drawio export CLI / other node tooling as needed
# ===========================================================================

log "node stage skeleton complete (no packages wired yet)."
