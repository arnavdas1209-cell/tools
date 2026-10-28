#!/usr/bin/env bash
#
# latex.sh - Tier 1 smoke test: latexmk builds notes/latex/demo.tex (minted ->
# -shell-escape; biber for the bibliography).
#
# Exit codes: 0 PASS, 2 SKIP (toolchain absent), other nonzero FAIL.
set -euo pipefail

echo "TIER=1"

if ! command -v latexmk >/dev/null 2>&1; then
  echo "NOTE=latexmk/texlive absent on host; runs in Ubuntu 24.04 devcontainer/CI (apt texlive-*)"
  echo "SKIP: latexmk not installed"
  exit 2
fi

VER="$(latexmk -v 2>/dev/null | head -n1 || true)"
echo "VERSION=${VER:-unknown}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEMO="${REPO_ROOT}/notes/latex/demo.tex"

if [ ! -f "${DEMO}" ]; then
  echo "NOTE=missing ${DEMO}"
  echo "FAIL: demo.tex not found"
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

if latexmk -pdf -shell-escape -interaction=nonstopmode -halt-on-error \
    -outdir="${WORK}" -cd "${DEMO}" >"${WORK}/build.log" 2>&1; then
  if [ -f "${WORK}/demo.pdf" ]; then
    echo "PASS: built demo.pdf"
    exit 0
  fi
  echo "NOTE=latexmk returned 0 but demo.pdf missing"
  echo "FAIL: no PDF produced"
  exit 1
fi

echo "NOTE=latexmk build failed; see build log tail below"
tail -n 15 "${WORK}/build.log" || true
echo "FAIL: latexmk build failed"
exit 1
