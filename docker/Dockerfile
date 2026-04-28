# headlights.nvim — reproducible test container.
#
# Build:
#   docker build -t headlights-test -f docker/Dockerfile .
#
# Run smoke test:
#   docker run --rm -t headlights-test make smoke
#
# Interactive shell with the plugin pre-installed:
#   docker run --rm -it headlights-test bash
#
# Open Neovim against the plugin:
#   docker run --rm -it headlights-test nvim --cmd 'set rtp+=/repo' \
#     -c 'runtime plugin/headlights.lua' -c 'Headlights buffer'

FROM ubuntu:24.04

ARG NVIM_VERSION=v0.10.4

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

# Minimal toolchain. We deliberately avoid `apt install neovim` because the
# distro version lags upstream; we fetch the exact release tarball instead.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        make \
        xz-utils \
        tini \
    && rm -rf /var/lib/apt/lists/*

# Install Neovim from the official tarball. Ubuntu 24.04 (noble) ships glibc
# new enough for the linux-x86_64 build.
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
      x86_64)  url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux64.tar.gz" ;; \
      aarch64) url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-arm64.tar.gz" ;; \
      *)       echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fL -o /tmp/nvim.tar.gz "$url"; \
    mkdir -p /opt/nvim; \
    tar -xzf /tmp/nvim.tar.gz -C /opt/nvim --strip-components=1; \
    rm /tmp/nvim.tar.gz; \
    /opt/nvim/bin/nvim --version | head -1

ENV PATH=/opt/nvim/bin:$PATH

WORKDIR /repo

# Layer-cache test deps before copying source.
COPY Makefile /repo/Makefile
RUN make test-deps || true   # tolerate offline builds

COPY . /repo

# Default command: run the smoke test.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["make", "smoke"]
