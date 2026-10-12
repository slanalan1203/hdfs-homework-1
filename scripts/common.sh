#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
dc() { docker compose "$@"; }
require_docker() {
  command -v docker >/dev/null || { echo 'Install Docker with Compose first.' >&2; exit 1; }
  docker compose version >/dev/null
  docker info >/dev/null || { echo 'Start / resume Docker Desktop or Docker Engine.' >&2; exit 1; }
}
