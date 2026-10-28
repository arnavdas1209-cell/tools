#!/usr/bin/env bash
#
# 90_verify.sh - Discover and run every smoke test, honestly.
#
# Runs each tests/smoke/* with a 120s timeout and aggregates the results into a
# markdown table at docs/VERIFY_REPORT.md with columns:
#
#   tool | tier | version | PASS/FAIL/SKIP | seconds | note
#
# Honesty rule: a tool is only PASS when its smoke test exits 0. Missing tools
# must exit with the SKIP convention (see below) and are reported SKIP. The
# runner never hangs: the 120s timeout bounds every test.
#
# Smoke-test contract (each tests/smoke/<tool>.sh|.py):
#   - exit 0                -> PASS
#   - exit 2                -> SKIP (tool absent / not applicable here)
#   - any other nonzero     -> FAIL
#   - exit 124 (timeout)    -> FAIL (timed out)
#   Optional: a test may print machine-readable metadata lines to stdout:
#       TIER=<n>
#       VERSION=<string>
#       NOTE=<free text>
#     These are parsed (last occurrence wins) to populate the table columns.
#
# Tier filtering (CI job split): when the TIERS environment variable is set to a
# space-separated list of tier numbers (e.g. TIERS="1 2 3"), only tests whose
# tier is in that list are run; out-of-scope tiers are not executed at all (not
# even as SKIP rows), because they belong to a different CI job's report. Each
# test declares its tier with a literal `TIER=<n>` line, which we read with a
# grep WITHOUT executing the test, so filtering costs nothing. When TIERS is
# unset or empty, every discovered test runs (the host / full-matrix default).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SMOKE_DIR="${REPO_ROOT}/tests/smoke"
REPORT="${REPO_ROOT}/docs/VERIFY_REPORT.md"
PER_TEST_TIMEOUT=120
mkdir -p "${REPO_ROOT}/docs"

ENV_DETECT="${SCRIPT_DIR}/.env-detect"
if [ -f "${ENV_DETECT}" ]; then
  # shellcheck source=/dev/null
  . "${ENV_DETECT}"
fi

# Tier filter (space-separated list, e.g. "1 2 3"). Empty/unset => run all.
TIERS="${TIERS:-}"

# Read a test's declared tier WITHOUT executing it, by grepping its `TIER=<n>`
# line (shell tests write `echo "TIER=3"`, python tests print f"TIER={TIER}" but
# also carry a literal `TIER = <n>` assignment). Returns the number, or empty if
# the test declares no static tier.
tier_of() {
  local path="$1" t=""
  # Shell style: echo "TIER=3"  /  python print "TIER=3"
  t="$(grep -oE 'TIER=[0-9]+' "${path}" 2>/dev/null | head -n1 | sed 's/TIER=//')"
  if [ -z "${t}" ]; then
    # Python module constant: TIER = 3
    t="$(grep -oE '^TIER[[:space:]]*=[[:space:]]*[0-9]+' "${path}" 2>/dev/null | head -n1 | grep -oE '[0-9]+')"
  fi
  printf '%s' "${t}"
}

# True when a tier is in the requested TIERS list (or when TIERS is empty).
tier_in_scope() {
  local t="$1" want
  [ -z "${TIERS}" ] && return 0   # no filter -> everything is in scope
  # A test with no declarable static tier is always run (cannot be filtered out).
  [ -z "${t}" ] && return 0
  for want in ${TIERS}; do
    [ "${t}" = "${want}" ] && return 0
  done
  return 1
}

# Counters.
n_pass=0; n_fail=0; n_skip=0; n_total=0

# Collect table rows in a temp file so we can emit a header first.
rows_file="$(mktemp)"
trap 'rm -f "${rows_file}"' EXIT

run_one() {
  local test_path="$1"
  local base tool runner
  base="$(basename "${test_path}")"
  tool="${base%.*}"

  case "${test_path}" in
    *.py) runner=(python3 "${test_path}") ;;
    *.sh) runner=(bash "${test_path}") ;;
    *)    runner=(bash "${test_path}") ;;
  esac

  local out rc start end secs
  start="$(date +%s)"
  # Capture stdout+stderr; bound by timeout so we never hang.
  if out="$(timeout --kill-after=10s "${PER_TEST_TIMEOUT}" "${runner[@]}" 2>&1)"; then
    rc=0
  else
    rc=$?
  fi
  end="$(date +%s)"
  secs=$(( end - start ))

  # Parse optional metadata (last occurrence wins).
  local tier version note status
  tier="$(printf '%s\n' "${out}" | sed -n 's/^TIER=//p' | tail -n1)"
  version="$(printf '%s\n' "${out}" | sed -n 's/^VERSION=//p' | tail -n1)"
  note="$(printf '%s\n' "${out}" | sed -n 's/^NOTE=//p' | tail -n1)"

  case "${rc}" in
    0)   status="PASS"; n_pass=$(( n_pass + 1 )) ;;
    2)   status="SKIP"; n_skip=$(( n_skip + 1 )) ;;
    124) status="FAIL"; n_fail=$(( n_fail + 1 ))
         [ -z "${note}" ] && note="timed out after ${PER_TEST_TIMEOUT}s" ;;
    *)   status="FAIL"; n_fail=$(( n_fail + 1 )) ;;
  esac
  n_total=$(( n_total + 1 ))

  # Sanitize pipe characters so the markdown table stays intact.
  version="${version//|/\\|}"
  note="${note//|/\\|}"

  printf '| %s | %s | %s | %s | %s | %s |\n' \
    "${tool}" "${tier:-?}" "${version:-?}" "${status}" "${secs}" "${note:-}" \
    >> "${rows_file}"
}

# Discover tests (sorted). Tolerate an empty/missing smoke dir.
shopt -s nullglob
tests=()
if [ -d "${SMOKE_DIR}" ]; then
  for t in "${SMOKE_DIR}"/*.sh "${SMOKE_DIR}"/*.py; do
    tests+=("${t}")
  done
fi
# Sort for deterministic ordering.
IFS=$'\n' tests=($(printf '%s\n' "${tests[@]}" | sort)) || true
unset IFS

n_filtered=0
for t in "${tests[@]}"; do
  [ -f "${t}" ] || continue
  if ! tier_in_scope "$(tier_of "${t}")"; then
    n_filtered=$(( n_filtered + 1 ))
    continue   # out-of-scope tier: not executed (belongs to another CI job)
  fi
  run_one "${t}"
done

if [ -n "${TIERS}" ]; then
  echo "TIERS filter active ('${TIERS}'): ran ${n_total}, skipped-by-tier ${n_filtered}." >&2
fi

# Write the report.
{
  echo "# Verify Report"
  echo
  echo "_Generated by \`scripts/90_verify.sh\` on $(date -u +%Y-%m-%dT%H:%M:%SZ)._"
  echo
  echo "Each smoke test runs with a ${PER_TEST_TIMEOUT}s timeout. Honesty rule:"
  echo "a tool is PASS only when its smoke test exits 0; absent tools are SKIP."
  echo
  if [ -n "${TIERS}" ]; then
    echo "Tier filter: \`TIERS=\"${TIERS}\"\` - only these tiers were run;"
    echo "${n_filtered} out-of-scope test(s) were not executed (other CI job)."
    echo
  fi
  echo "Totals: ${n_pass} passed, ${n_fail} failed, ${n_skip} skipped (${n_total} tests)."
  echo
  echo "| tool | tier | version | PASS/FAIL/SKIP | seconds | note |"
  echo "| --- | --- | --- | --- | --- | --- |"
  if [ "${n_total}" -eq 0 ]; then
    echo "| _(no smoke tests discovered yet)_ |  |  |  |  | add tests under tests/smoke/ |"
  else
    # Sort rows by tier (numeric, column 3 after the leading '| '), then by tool
    # name (column 2). The leading pipe makes awk field 1 empty, so tool=$2 and
    # tier=$3 with FS=' | '. A missing tier ('?') sorts last via a large key.
    sort -t'|' -k3,3n -k2,2 "${rows_file}"
  fi
} > "${REPORT}"

echo "Wrote ${REPORT}"
echo "Totals: ${n_pass} passed, ${n_fail} failed, ${n_skip} skipped (${n_total} tests)."

# Exit nonzero only if something actually FAILED (SKIP is tolerated).
[ "${n_fail}" -eq 0 ]
