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
  cap npm install -g --no-fund --no-audit "$1"
}

# ===========================================================================
# TIER 1 (figures): @mermaid-js/mermaid-cli
#   mermaid-cli drives a headless chromium through puppeteer. In a container
#   there is no sandbox namespace support, so we point puppeteer at the system
#   chromium and pass --no-sandbox via a committed config file.
# ===========================================================================

# Locate a system chromium for puppeteer to reuse (avoids downloading one).
CHROMIUM_BIN=""
for c in chromium chromium-browser google-chrome google-chrome-stable; do
  if command -v "$c" >/dev/null 2>&1; then CHROMIUM_BIN="$(command -v "$c")"; break; fi
done
[ -n "${CHROMIUM_BIN}" ] || CHROMIUM_BIN="/usr/bin/chromium"

# Puppeteer config consumed by mermaid-cli via `mmdc -p <puppeteer.json>`.
PUPPETEER_CFG="${SCRIPT_DIR}/puppeteer-config.json"
cat > "${PUPPETEER_CFG}" <<JSON
{
  "executablePath": "${CHROMIUM_BIN}",
  "args": ["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"]
}
JSON
log "Wrote puppeteer config ${PUPPETEER_CFG} (chromium=${CHROMIUM_BIN}, --no-sandbox)."

# Tell puppeteer not to download its own chromium at install time.
export PUPPETEER_SKIP_DOWNLOAD=1
export PUPPETEER_EXECUTABLE_PATH="${CHROMIUM_BIN}"

log "TIER 1: installing @mermaid-js/mermaid-cli."
npm_global "@mermaid-js/mermaid-cli"

# ===========================================================================
# TIER 1 (figures): drawio-desktop
#   drawio-desktop is an Electron app; it exports diagrams from the CLI but must
#   run under a virtual framebuffer on a headless host. The smoke test and the
#   README document the xvfb-run invocation:
#     xvfb-run -a drawio --no-sandbox -x -f pdf -o out.pdf input.drawio
# ===========================================================================
log "TIER 1: installing drawio-desktop (CLI export runs under xvfb-run)."
npm_global "drawio-desktop"

log "node stage complete (mermaid-cli + drawio-desktop; puppeteer->system chromium)."
