#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_docker
dc config --quiet
dc build namenode
if ! dc up -d --wait --wait-timeout 240; then
  dc ps -a >&2
  dc logs --no-color --tail 100 >&2
  exit 1
fi
bash "$PROJECT_DIR/scripts/verify.sh"
echo 'NameNode UI: http://localhost:9870/dfshealth.html#tab-datanode'
