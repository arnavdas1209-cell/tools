#!/usr/bin/env bash
#
# graphviz.sh - Tier 1 smoke test: dot renders a trivial graph to SVG.
#
# Exit codes: 0 PASS, 2 SKIP (dot absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=1"

if ! command -v dot >/dev/null 2>&1; then
  echo "NOTE=graphviz (dot) absent on host; apt graphviz in devcontainer/CI"
  echo "SKIP: dot not installed"
  exit 2
fi

VER="$(dot -V 2>&1 | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

cat > "${WORK}/g.dot" <<'DOT'
digraph G { rankdir=LR; A -> B -> C; A -> C; }
DOT

if dot -Tsvg "${WORK}/g.dot" -o "${WORK}/g.svg" >"${WORK}/log" 2>&1 && [ -s "${WORK}/g.svg" ]; then
  echo "PASS: dot rendered SVG"
  exit 0
fi

echo "NOTE=dot failed to render SVG"
tail -n 15 "${WORK}/log" || true
echo "FAIL: graphviz render failed"
exit 1
