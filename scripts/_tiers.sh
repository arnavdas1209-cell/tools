# _tiers.sh - shared tier-gating helper, sourced by the install stages.
#
# The CI workflow splits the install/verify matrix by tier: the push/PR job runs
# tiers 1-3 and the nightly job runs tiers 4-6. It expresses that split with the
# TIERS environment variable (e.g. TIERS="1 2 3"). This helper lets each stage
# install ONLY the requested tiers' packages, so the two CI jobs do different,
# non-overlapping work instead of both running the full matrix.
#
# Contract:
#   - TIERS is a space-separated list of tier numbers (e.g. "1 2 3").
#   - When TIERS is unset or empty, EVERY tier is enabled (the host / full-matrix
#     default, and what `make setup` does when invoked without TIERS).
#   - `tier_enabled <n>` returns 0 (true) when tier <n> should be installed.
#
# This file is meant to be sourced, not executed, so it defines a function and
# does not set shell options of its own.

# tier_enabled <n> -> 0 if tier <n> is in scope, 1 otherwise.
tier_enabled() {
  local want="$1" t
  # No filter configured => run everything.
  [ -z "${TIERS:-}" ] && return 0
  for t in ${TIERS}; do
    [ "${t}" = "${want}" ] && return 0
  done
  return 1
}
