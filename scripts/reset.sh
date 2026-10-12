#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
if [[ "${1:-}" != --delete-all-data ]]; then
  echo 'Deletes ALL HDFS data. To confirm: bash scripts/reset.sh --delete-all-data' >&2
  exit 2
fi
require_docker
dc down --volumes
