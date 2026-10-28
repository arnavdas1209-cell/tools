# Scientific-Computing Workspace

A fully reproducible, **headless** (no GUI, no GPU), open-source engineering and
materials-science workspace: Ubuntu 24.04 devcontainer, per-domain conda-forge
environments, numbered install scripts, honest smoke tests, and GitHub Actions CI.

> Status: scaffolding (FEAT-001). Tier tooling, env YAMLs, and smoke tests are
> added by later features.

## Quick start

Inside the devcontainer (or any Ubuntu 24.04 host):

```bash
make setup    # detect environment, then run install stages 10..50 in order
make verify   # run every smoke test -> docs/VERIFY_REPORT.md
make report   # print docs/ENV_REPORT.md and docs/VERIFY_REPORT.md
make clean    # remove build artifacts (keeps source)
```

## Layout

| Path | Purpose |
| --- | --- |
| `.devcontainer/` | Ubuntu 24.04 headless devcontainer (Dockerfile + devcontainer.json) |
| `envs/` | Per-domain conda-forge environment YAMLs (core, fea, atomistic, cad, chem) |
| `scripts/` | Numbered install stages (`00_detect` .. `50_docker_images`) + `90_verify` |
| `tests/smoke/` | One smoke test per tool (PASS/FAIL/SKIP, 120s timeout) |
| `templates/` | LaTeX block-notes template |
| `notes/` | latex / obsidian-vault / notebooks / quarto |
| `figures/` | tikz / python / mermaid / drawio outputs |
| `refs/` | BibTeX library |
| `docs/` | README, UNSUPPORTED, generated ENV_REPORT & VERIFY_REPORT |
| `.github/workflows/` | CI: tiers 1-3 on push, tiers 4-5 nightly |

## Honesty rule

A tool is never marked **PASS** until its smoke test actually passes. Anything
that cannot install in a headless Linux container is recorded in
[`docs/UNSUPPORTED.md`](UNSUPPORTED.md) with the reason and a fallback.

## Environment detection

`scripts/00_detect.sh` measures CPU/RAM/disk and detects docker, apptainer,
sudo, conda and apt. It writes [`docs/ENV_REPORT.md`](ENV_REPORT.md) and a
sourceable `scripts/.env-detect`. Heavy items (MOOSE/PRISMS-PF, OpenFOAM,
Code_Aster, texlive-fonts-extra) are gated behind `HEAVY_OK=1`
(RAM >= 16 GB and free disk >= 40 GB).
