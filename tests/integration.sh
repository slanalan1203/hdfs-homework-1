#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
bash scripts/up.sh
expected="persistence-check-$(date +%s)"
printf '%s\n' "$expected" | docker compose exec -T --user hadoop namenode hdfs dfs -put -f - /homework/persistence.txt
bash scripts/down.sh
bash scripts/up.sh
actual="$(docker compose exec -T --user hadoop namenode hdfs dfs -cat /homework/persistence.txt)"
if [[ "$actual" != "$expected" ]]; then
  echo 'FAIL: file did not survive container recreation' >&2
  exit 1
fi
echo 'PASS: file survived container recreation'
