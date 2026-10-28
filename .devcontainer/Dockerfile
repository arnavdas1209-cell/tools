# Reproducible, headless (no GUI, no GPU) scientific-computing workspace.
# Base image: Ubuntu 24.04 LTS.
FROM ubuntu:24.04

LABEL org.opencontainers.image.title="sci-workspace devcontainer" \
      org.opencontainers.image.description="Headless Ubuntu 24.04 engineering & materials-science workspace" \
      org.opencontainers.image.source="https://github.com/"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    # Headless / offscreen rendering defaults.
    PYVISTA_OFF_SCREEN=true \
    MPLBACKEND=Agg \
    DISPLAY=:99

# ---------------------------------------------------------------------------
# Base apt dependencies (authored for Ubuntu 24.04). Tier-specific packages are
# installed later by scripts/10_apt.sh; here we install only what the container
# itself needs: toolchain basics, headless rendering libs, xvfb, and sudo.
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      wget \
      git \
      bzip2 \
      xz-utils \
      unzip \
      build-essential \
      pkg-config \
      locales \
      sudo \
      procps \
      # headless / offscreen graphics
      xvfb \
      libgl1 \
      libglu1-mesa \
      libosmesa6 \
      libegl1 \
      # fonts for figures/latex rendering
      fontconfig \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Non-root user (headless devcontainer best practice). 'vscode' with passwordless
# sudo for apt only; conda/pip/npm run as this user and never via sudo.
# ---------------------------------------------------------------------------
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
# Ubuntu 24.04 ships a default uid=1000 'ubuntu' user; remove it to free the uid.
RUN (userdel -r ubuntu 2>/dev/null || true) \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# ---------------------------------------------------------------------------
# Miniforge (conda + mamba, conda-forge default channel) installed per-user.
# ---------------------------------------------------------------------------
ENV CONDA_DIR=/opt/conda
ENV PATH=${CONDA_DIR}/bin:${PATH}
RUN arch="$(uname -m)" \
    && url="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${arch}.sh" \
    && curl -fsSL "${url}" -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p ${CONDA_DIR} \
    && rm -f /tmp/miniforge.sh \
    && ${CONDA_DIR}/bin/conda config --system --set channel_priority strict \
    && ${CONDA_DIR}/bin/conda clean -afy \
    && chown -R ${USERNAME}:${USERNAME} ${CONDA_DIR}

# ---------------------------------------------------------------------------
# Node.js (via NodeSource) for mermaid-cli / drawio export tooling.
# ---------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

USER ${USERNAME}
WORKDIR /workspaces
# Make conda available in interactive shells for the non-root user.
RUN ${CONDA_DIR}/bin/conda init bash

CMD ["sleep", "infinity"]
