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

# --- tier gating (CI job split: tiers 1-3 push, tiers 4-6 nightly) ----------
# shellcheck source=/dev/null
. "${SCRIPT_DIR}/_tiers.sh"
[ -n "${TIERS:-}" ] && log "tier filter active: TIERS='${TIERS}' (only these tiers install)."

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

if tier_enabled 1; then
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
else
  log "SKIP TIER 1 node tools (mermaid-cli, drawio-desktop) (not in TIERS='${TIERS}')."
fi

# ===========================================================================
# TIER 2 (chemistry): Ketcher static site (epam/ketcher)
#   Ketcher is a web-based 2D chemical structure editor. We clone the repo,
#   npm-install, and build the standalone example into a static bundle that can
#   be served by any static HTTP server (no backend required for drawing).
#   The whole build is capped at 30 min; on failure we document it in
#   docs/UNSUPPORTED.md and move on (do not loop).
#
#   Start command (documented in docs/README.md):
#     npx http-server "${REPO_ROOT}/.local/ketcher" -p 8080
#   then open http://localhost:8080/ in a browser.
# ===========================================================================
KETCHER_DIR="${REPO_ROOT}/.local/ketcher-src"
KETCHER_SITE="${REPO_ROOT}/.local/ketcher"
KETCHER_REF="v2.24.0"   # pinned release tag; adjust after a successful build

build_ketcher() {
  log "TIER 2: building self-hosted Ketcher static site (epam/ketcher @ ${KETCHER_REF})."

  if ! command -v git >/dev/null 2>&1; then
    log "ERROR: git not available; cannot clone Ketcher."
    return 1
  fi

  rm -rf "${KETCHER_DIR}"
  if ! cap git clone --depth 1 --branch "${KETCHER_REF}" \
        https://github.com/epam/ketcher.git "${KETCHER_DIR}"; then
    log "Pinned tag clone failed; retrying default branch (one fallback)."
    rm -rf "${KETCHER_DIR}"
    cap git clone --depth 1 https://github.com/epam/ketcher.git "${KETCHER_DIR}" || return 1
  fi

  # Ketcher is an npm monorepo. Install + build the standalone demo package,
  # which emits a self-contained static bundle under its `dist/` directory.
  (
    cd "${KETCHER_DIR}" || exit 1
    cap npm ci --no-fund --no-audit || cap npm install --no-fund --no-audit || exit 1
    # The example/standalone app builds a backend-free static site.
    cap npm run build:standalone || cap npm run build || exit 1
  ) || return 1

  # Locate the produced static bundle (package layout varies by release).
  local dist=""
  for d in \
      "${KETCHER_DIR}/example/dist" \
      "${KETCHER_DIR}/packages/ketcher-standalone/dist" \
      "${KETCHER_DIR}/dist"; do
    if [ -d "${d}" ] && [ -n "$(ls -A "${d}" 2>/dev/null)" ]; then dist="${d}"; break; fi
  done
  if [ -z "${dist}" ]; then
    log "ERROR: Ketcher build produced no recognizable dist/ directory."
    return 1
  fi

  rm -rf "${KETCHER_SITE}"
  mkdir -p "${KETCHER_SITE}"
  cp -r "${dist}/." "${KETCHER_SITE}/"
  log "Ketcher static site ready at ${KETCHER_SITE} (serve with: npx http-server ${KETCHER_SITE} -p 8080)."
  return 0
}

if tier_enabled 2; then
if ! build_ketcher; then
  UNSUP="${REPO_ROOT}/docs/UNSUPPORTED.md"
  log "Ketcher build failed/capped; recording in ${UNSUP} and moving on."
  {
    echo ""
    echo "<!-- auto-appended by scripts/30_node.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ) -->"
    echo "- **Ketcher** (epam/ketcher): static-site build failed or exceeded the 30-min cap"
    echo "  on this host. Fallback: use RDKit / Indigo for programmatic 2D rendering, or run"
    echo "  the official \`epmlsop/ketcher-standalone\` Docker image. Re-run \`scripts/30_node.sh\`"
    echo "  in the devcontainer/CI where node + network are available."
  } >> "${UNSUP}"
fi
else
  log "SKIP TIER 2 Ketcher static-site build (not in TIERS='${TIERS}')."
fi

log "node stage complete (tier-gated: mermaid-cli + drawio-desktop + Ketcher; puppeteer->system chromium)."
