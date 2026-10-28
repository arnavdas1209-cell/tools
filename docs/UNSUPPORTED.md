# Unsupported / Skipped Tools

Per the honesty rule, any tool that cannot install or pass its smoke test in the
headless Linux container is recorded here with the **reason** and a **fallback**.
Do not loop on failures: try one alternative (conda-forge -> pip -> Docker/Apptainer
image), then document it here and move on.

## Tier 1 (notes + diagrams + plotting)

On the authoring/validation host (Amazon Linux 2023: no apt, no conda, no npm),
only the pure-Python core stack can actually execute. Everything that needs
apt/node/binary installs is **SKIP here** and runs for real in the Ubuntu 24.04
devcontainer / GitHub Actions CI. These are not failures: the smoke tests emit
exit 2 (SKIP) with a NOTE, per the honesty rule.

| Tool | Tier | Reason skipped/failed (on host) | Fallback / where it runs | Final status |
| --- | --- | --- | --- | --- |
| latex (texlive/latexmk/biber) | 1 | No apt on Amazon Linux 2023; TeX Live not installed | apt in devcontainer/CI | SKIP (host) |
| mermaid (mermaid-cli) | 1 | No npm/node on host | `scripts/30_node.sh` in devcontainer/CI (puppeteer -> system chromium, --no-sandbox) | SKIP (host) |
| graphviz (dot) | 1 | No apt on host | apt `graphviz` in devcontainer/CI | SKIP (host) |
| inkscape | 1 | No apt on host | apt `inkscape` (headless) in devcontainer/CI | SKIP (host) |
| drawio (drawio-desktop) | 1 | No npm + no xvfb on host | `scripts/30_node.sh`; run under `xvfb-run` in devcontainer/CI | SKIP (host) |
| octave | 1 | No apt on host | apt `octave` in devcontainer/CI | SKIP (host) |
| scilab | 1 | No apt on host | apt `scilab` in devcontainer/CI | SKIP (host) |
| gnuplot | 1 | No apt on host | apt `gnuplot` in devcontainer/CI | SKIP (host) |
| grace (gracebat) | 1 | No apt on host | apt `grace` in devcontainer/CI | SKIP (host) |
| openscad | 1 | No apt on host | apt `openscad` in devcontainer/CI | SKIP (host) |
| veusz | 1 | Not importable on host (no apt/conda) | apt `veusz` / conda-forge in devcontainer/CI | SKIP (host) |
| typst | 1 | Release binary not installed on host | `scripts/40_binaries.sh` (GitHub release) in devcontainer/CI | staged (no host smoke) |
| quarto | 1 | Release tarball not installed on host | `scripts/40_binaries.sh` (GitHub release) in devcontainer/CI | staged (no host smoke) |

> `core-python` (numpy/scipy/sympy/matplotlib/schemdraw) is the one Tier 1 test
> that **actually PASSED** on this host via a throwaway `/tmp` venv.

> Status note: `scipy-stats-extras` is intentionally omitted from `envs/core.yml`
> because no such conda-forge package exists; `scipy.stats` already provides the
> extended statistics API, so no fallback is needed.
