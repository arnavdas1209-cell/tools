# Makefile - build harness for the reproducible scientific-computing workspace.
#
# Targets:
#   make setup   - detect environment, then run install stages 10..50 in order
#                  (each stage is guarded: a failing stage is logged, not fatal)
#   make verify  - run all smoke tests and write docs/VERIFY_REPORT.md
#   make report  - print docs/ENV_REPORT.md and docs/VERIFY_REPORT.md
#   make clean   - remove build artifacts (envs, node_modules, LaTeX aux) but
#                  never the source files
#
# Intended to run INSIDE the Ubuntu 24.04 devcontainer. On other hosts the
# install stages detect missing tooling and skip gracefully.

SHELL := /usr/bin/env bash
SCRIPTS := scripts
DOCS := docs

.DEFAULT_GOAL := help

.PHONY: help setup verify report clean detect

help:
	@echo "Targets: setup | verify | report | clean | detect"
	@echo "  make setup   - detect env + run install stages 10..50 (guarded)"
	@echo "  make verify  - run smoke tests -> $(DOCS)/VERIFY_REPORT.md"
	@echo "  make report  - print ENV_REPORT.md + VERIFY_REPORT.md"
	@echo "  make clean   - remove build artifacts (keeps source)"

detect:
	@bash $(SCRIPTS)/00_detect.sh

# setup: run detection first, then each install stage in order. Each stage is
# guarded with `|| ...` so a failing stage is logged and setup continues.
#
# Tier filtering: the optional TIERS variable (space-separated tier numbers,
# e.g. `make setup TIERS="1 2 3"`) is exported to every stage, which installs
# only the requested tiers' packages (see scripts/_tiers.sh). The CI workflow
# uses this to split work: the push/PR job runs tiers 1-3 and the nightly job
# runs tiers 4-6. When TIERS is unset, every stage installs all tiers.
export TIERS
setup:
	@bash $(SCRIPTS)/00_detect.sh
	@echo "setup: TIERS='$(TIERS)' (empty => all tiers)"
	@for stage in 10_apt 20_conda 30_node 40_binaries 50_docker_images; do \
		echo "=== running $$stage ==="; \
		bash $(SCRIPTS)/$$stage.sh || echo "WARN: stage $$stage exited nonzero (logged, continuing)"; \
	done
	@echo "setup complete; run 'make verify' to run smoke tests."

verify:
	@bash $(SCRIPTS)/90_verify.sh

report:
	@echo "===================== docs/ENV_REPORT.md ====================="
	@if [ -f $(DOCS)/ENV_REPORT.md ]; then cat $(DOCS)/ENV_REPORT.md; else echo "(missing; run 'make detect' or 'make setup')"; fi
	@echo
	@echo "=================== docs/VERIFY_REPORT.md ===================="
	@if [ -f $(DOCS)/VERIFY_REPORT.md ]; then cat $(DOCS)/VERIFY_REPORT.md; else echo "(missing; run 'make verify')"; fi

clean:
	@echo "Removing build artifacts (source is preserved)..."
	@rm -rf .local/ envs/_build/ node_modules notes/**/node_modules 2>/dev/null || true
	@# conda envs created by name live in the conda install, not the repo; remove
	@# any repo-local env prefixes if present.
	@rm -rf .conda/ miniforge/ mambaforge/ 2>/dev/null || true
	@# LaTeX aux files.
	@find . -type f \( -name '*.aux' -o -name '*.log' -o -name '*.out' -o -name '*.toc' \
		-o -name '*.fls' -o -name '*.fdb_latexmk' -o -name '*.synctex.gz' \
		-o -name '*.bbl' -o -name '*.blg' \) -not -path './.git/*' -delete 2>/dev/null || true
	@# Python caches.
	@find . -type d -name '__pycache__' -not -path './.git/*' -exec rm -rf {} + 2>/dev/null || true
	@echo "clean complete."
