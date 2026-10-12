#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_docker
dc down
echo 'Stopped. All five data volumes are preserved.'
