#!/usr/bin/env bash
# docker-test.sh — build the headlights test image and run the smoke test
# inside it. Useful for validating the plugin on a remote Linux host without
# touching the host's Neovim install.
#
# Usage:
#   scripts/docker-test.sh                    # smoke test
#   scripts/docker-test.sh make test          # full suite
#   scripts/docker-test.sh bash               # drop into a shell
#   scripts/docker-test.sh bin/headlights --format=json
#
# Environment:
#   DOCKER_IMAGE=headlights-test              # override image tag

set -eu

IMAGE="${DOCKER_IMAGE:-headlights-test}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found on PATH" >&2
  exit 127
fi

echo "==> building $IMAGE"
docker build -t "$IMAGE" -f "$REPO_ROOT/docker/Dockerfile" "$REPO_ROOT"

echo "==> running"
if [ "$#" -eq 0 ]; then
  exec docker run --rm -t "$IMAGE"
else
  exec docker run --rm -it "$IMAGE" "$@"
fi
