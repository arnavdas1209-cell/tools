#!/usr/bin/env bash
#
# mermaid.sh - Tier 1 smoke test: @mermaid-js/mermaid-cli renders a flowchart
# to SVG using the committed puppeteer config (system chromium, --no-sandbox).
#
# Exit codes: 0 PASS, 2 SKIP (mmdc absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=1"

if ! command -v mmdc >/dev/null 2>&1; then
  echo "NOTE=mermaid-cli (mmdc) absent on host; installed by scripts/30_node.sh in devcontainer/CI"
  echo "SKIP: mmdc not installed"
  exit 2
fi

VER="$(mmdc --version 2>/dev/null | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PCFG="${REPO_ROOT}/scripts/puppeteer-config.json"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cat > "${WORK}/flow.mmd" <<'MMD'
flowchart TD
    A[Start] --> B{Decision}
    B -->|yes| C[Do thing]
    B -->|no| D[Skip]
    C --> E[End]
    D --> E
MMD

CFG_ARGS=()
[ -f "${PCFG}" ] && CFG_ARGS=(-p "${PCFG}")

if mmdc "${CFG_ARGS[@]}" -i "${WORK}/flow.mmd" -o "${WORK}/flow.svg" >"${WORK}/log" 2>&1; then
  if [ -s "${WORK}/flow.svg" ]; then
    echo "PASS: rendered flowchart to SVG"
    exit 0
  fi
  echo "NOTE=mmdc returned 0 but SVG empty/missing"
  echo "FAIL: no SVG produced"
  exit 1
fi

echo "NOTE=mmdc render failed (headless chromium?); see log"
tail -n 15 "${WORK}/log" || true
echo "FAIL: mermaid render failed"
exit 1
