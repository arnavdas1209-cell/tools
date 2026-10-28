#!/usr/bin/env bash
#
# 00_detect.sh - Environment detection for the scientific-computing workspace.
#
# Measures CPU / RAM / disk and detects whether docker, apptainer/singularity,
# sudo, conda/mamba and apt are present and working. Writes two artifacts:
#
#   scripts/.env-detect   - sourceable KEY=VALUE file consumed by the install
#                           stage scripts (10..50) and 90_verify.sh
#   docs/ENV_REPORT.md     - human-readable report
#
# Heavy-tier gate: HEAVY_OK=1 only when RAM_GB>=16 && DISK_GB>=40. When HEAVY_OK
# is 0 the heavy items (MOOSE/PRISMS-PF, OpenFOAM, Code_Aster, texlive-fonts-extra)
# are skipped by later stages.
#
# Docker note: the host `docker` may be a broken podman shim, so presence on PATH
# is NOT enough. We test `docker info` and only set HAS_DOCKER=1 when it works.
#
# Apptainer->Docker fallback: CONTAINER_RUNTIME records the preferred working
# container runtime (apptainer first, else docker, else none).
set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths relative to this script so it works from any CWD.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_DETECT="${SCRIPT_DIR}/.env-detect"
ENV_REPORT="${REPO_ROOT}/docs/ENV_REPORT.md"

mkdir -p "${REPO_ROOT}/docs"

# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# CPU.
# ---------------------------------------------------------------------------
if have nproc; then
  CPU_COUNT="$(nproc)"
else
  CPU_COUNT="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
fi

# ---------------------------------------------------------------------------
# RAM in whole GB (GiB-ish; good enough for tier gating).
# ---------------------------------------------------------------------------
RAM_GB=0
if [ -r /proc/meminfo ]; then
  mem_kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
  RAM_GB=$(( mem_kb / 1024 / 1024 ))
elif have sysctl; then
  mem_b="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
  RAM_GB=$(( mem_b / 1024 / 1024 / 1024 ))
fi

# ---------------------------------------------------------------------------
# Free disk in whole GB on the workspace mount.
# ---------------------------------------------------------------------------
DISK_GB=0
if have df; then
  # -P = POSIX output, -k = 1K blocks (portable; -BG not available everywhere).
  avail_k="$(df -Pk "${REPO_ROOT}" | awk 'NR==2 {print $4}')"
  DISK_GB=$(( avail_k / 1024 / 1024 ))
fi

# ---------------------------------------------------------------------------
# Container runtime: docker (test `docker info`, not just PATH).
# ---------------------------------------------------------------------------
HAS_DOCKER=0
DOCKER_NOTE="not found on PATH"
if have docker; then
  if docker info >/dev/null 2>&1; then
    HAS_DOCKER=1
    DOCKER_NOTE="present and working (docker info ok)"
  else
    DOCKER_NOTE="present on PATH but NOT working (docker info failed; likely broken podman/conmon shim)"
  fi
fi

# ---------------------------------------------------------------------------
# apptainer / singularity.
# ---------------------------------------------------------------------------
HAS_APPTAINER=0
APPTAINER_BIN=""
if have apptainer; then
  HAS_APPTAINER=1
  APPTAINER_BIN="apptainer"
elif have singularity; then
  HAS_APPTAINER=1
  APPTAINER_BIN="singularity"
fi

# ---------------------------------------------------------------------------
# Apptainer -> Docker fallback: choose preferred working container runtime.
# ---------------------------------------------------------------------------
if [ "${HAS_APPTAINER}" -eq 1 ]; then
  CONTAINER_RUNTIME="${APPTAINER_BIN}"
elif [ "${HAS_DOCKER}" -eq 1 ]; then
  CONTAINER_RUNTIME="docker"
else
  CONTAINER_RUNTIME="none"
fi

# ---------------------------------------------------------------------------
# sudo.
# ---------------------------------------------------------------------------
HAS_SUDO=0
have sudo && HAS_SUDO=1

# ---------------------------------------------------------------------------
# conda / mamba.
# ---------------------------------------------------------------------------
HAS_CONDA=0
CONDA_BIN=""
if have mamba; then
  HAS_CONDA=1
  CONDA_BIN="mamba"
elif have conda; then
  HAS_CONDA=1
  CONDA_BIN="conda"
fi

# ---------------------------------------------------------------------------
# apt (Debian/Ubuntu only).
# ---------------------------------------------------------------------------
HAS_APT=0
have apt-get && HAS_APT=1

# ---------------------------------------------------------------------------
# Heavy-tier gate.
# ---------------------------------------------------------------------------
HEAVY_OK=0
if [ "${RAM_GB}" -ge 16 ] && [ "${DISK_GB}" -ge 40 ]; then
  HEAVY_OK=1
fi

# ---------------------------------------------------------------------------
# Write sourceable detect file.
# ---------------------------------------------------------------------------
cat > "${ENV_DETECT}" <<EOF
# Generated by scripts/00_detect.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Sourceable: KEY=VALUE pairs consumed by install stages and 90_verify.sh.
CPU_COUNT=${CPU_COUNT}
RAM_GB=${RAM_GB}
DISK_GB=${DISK_GB}
HAS_DOCKER=${HAS_DOCKER}
HAS_APPTAINER=${HAS_APPTAINER}
HAS_SUDO=${HAS_SUDO}
HAS_CONDA=${HAS_CONDA}
HAS_APT=${HAS_APT}
HEAVY_OK=${HEAVY_OK}
CONTAINER_RUNTIME=${CONTAINER_RUNTIME}
APPTAINER_BIN=${APPTAINER_BIN}
CONDA_BIN=${CONDA_BIN}
EOF

# ---------------------------------------------------------------------------
# Write human-readable report.
# ---------------------------------------------------------------------------
heavy_status="ENABLED (resources meet thresholds)"
if [ "${HEAVY_OK}" -ne 1 ]; then
  heavy_status="DISABLED (insufficient RAM or disk)"
fi

cat > "${ENV_REPORT}" <<EOF
# Environment Report

_Generated by \`scripts/00_detect.sh\` on $(date -u +%Y-%m-%dT%H:%M:%SZ)._

## Measured resources

| Metric | Value |
| --- | --- |
| CPU count | ${CPU_COUNT} |
| RAM (GB) | ${RAM_GB} |
| Free disk on workspace mount (GB) | ${DISK_GB} |

## Capability detection

| Capability | Detected | Note |
| --- | --- | --- |
| Docker | $( [ "${HAS_DOCKER}" -eq 1 ] && echo yes || echo no ) | ${DOCKER_NOTE} |
| Apptainer / Singularity | $( [ "${HAS_APPTAINER}" -eq 1 ] && echo yes || echo no ) | ${APPTAINER_BIN:-absent} |
| sudo | $( [ "${HAS_SUDO}" -eq 1 ] && echo yes || echo no ) | |
| conda / mamba | $( [ "${HAS_CONDA}" -eq 1 ] && echo yes || echo no ) | ${CONDA_BIN:-absent} |
| apt | $( [ "${HAS_APT}" -eq 1 ] && echo yes || echo no ) | Debian/Ubuntu only |

## Container runtime selection (Apptainer -> Docker fallback)

Preferred working container runtime: **${CONTAINER_RUNTIME}**

The workspace prefers Apptainer/Singularity (rootless, HPC-friendly). When
Apptainer is absent it falls back to Docker, but only if \`docker info\`
succeeds. On a host where \`docker\` is a broken podman shim both are
unavailable and container-image tools are reported SKIP by the smoke tests.

## Heavy-tier gate

\`HEAVY_OK=${HEAVY_OK}\` -> heavy tier is **${heavy_status}**.

Heavy items are gated behind \`HEAVY_OK=1\` (RAM >= 16 GB **and** free disk >= 40 GB).
If disk or RAM are short, these are skipped and the reason is recorded here and
in \`docs/UNSUPPORTED.md\`:

- MOOSE / PRISMS-PF
- OpenFOAM
- Code_Aster
- texlive-fonts-extra

## How this is used

- \`scripts/.env-detect\` is sourced by \`scripts/10_apt.sh\` .. \`scripts/50_docker_images.sh\`
  and by \`scripts/90_verify.sh\`.
- Later install stages consult \`HEAVY_OK\`, \`HAS_CONDA\`, \`HAS_APT\`, \`HAS_DOCKER\`
  and \`CONTAINER_RUNTIME\` to decide what to attempt and what to skip.
EOF

echo "Wrote ${ENV_DETECT}"
echo "Wrote ${ENV_REPORT}"
echo "CPU=${CPU_COUNT} RAM_GB=${RAM_GB} DISK_GB=${DISK_GB} HEAVY_OK=${HEAVY_OK} CONTAINER_RUNTIME=${CONTAINER_RUNTIME}"
