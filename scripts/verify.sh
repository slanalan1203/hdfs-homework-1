#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_docker
mkdir -p reports
rm -f reports/checked-at.txt
trap 'echo "Verification failed. See reports/ and docker compose logs." >&2' ERR

# HTTP health is a prerequisite; registration and storage are checked separately.
for service in namenode secondarynamenode datanode1 datanode2 datanode3; do
  container="$(dc ps -q "$service")"
  if [[ -z "$container" || "$(docker inspect --format '{{.State.Health.Status}}' "$container")" != healthy ]]; then
    echo "FAIL: $service is not healthy" >&2
    exit 1
  fi
done

ready=false
for ((attempt=0; attempt<60; attempt++)); do
  if dc exec -T --user hadoop namenode curl -fsS --max-time 5 \
      'http://localhost:9870/jmx?qry=Hadoop:service=NameNode,name=NameNodeInfo' > reports/namenode-jmx.json \
      && dc exec -T --user hadoop namenode python3 /usr/local/bin/check-nodes.py < reports/namenode-jmx.json > reports/nodes.txt 2>&1; then
    ready=true
    break
  fi
  sleep 2
done
cat reports/nodes.txt
[[ "$ready" == true ]]
dc exec -T --user hadoop namenode hdfs dfsadmin -report > reports/dfsadmin-report.txt
dc exec -T --user hadoop namenode hdfs dfsadmin -safemode get > reports/safemode.txt
grep -q 'Safe mode is OFF' reports/safemode.txt

checkpoint_id() {
  dc exec -T --user hadoop secondarynamenode python3 -c '
from pathlib import Path
ids = [int(p.name[8:]) for p in Path("/data/checkpoint/current").glob("fsimage_*")
       if p.is_file() and p.name[8:].isdigit() and p.stat().st_size > 0]
print(max(ids, default=0))'
}
checkpoint_before="$(checkpoint_id)"
expected='HDFS homework: three DataNodes and replication=3'
dc exec -T --user hadoop namenode hdfs dfs -mkdir -p /homework
printf '%s\n' "$expected" | dc exec -T --user hadoop namenode hdfs dfs -put -f - /homework/hello.txt
actual="$(dc exec -T --user hadoop namenode hdfs dfs -cat /homework/hello.txt)"
[[ "$actual" == "$expected" ]]

# Bounded wait for real replication, rather than only the configured factor.
replicated=false
for ((attempt=0; attempt<60; attempt++)); do
  if dc exec -T --user hadoop namenode hdfs fsck /homework/hello.txt -files -blocks -locations > reports/fsck.txt 2>&1 \
      && grep -q 'Status: HEALTHY' reports/fsck.txt \
      && grep -q 'Live_repl=3' reports/fsck.txt; then
    replicated=true
    break
  fi
  sleep 2
done
cat reports/fsck.txt
[[ "$replicated" == true ]]
echo 'PASS: write/read and three actual block replicas'

# Require progress after this test's write; a persisted old image is insufficient.
checkpoint=false
for ((attempt=0; attempt<60; attempt++)); do
  if checkpoint_current="$(checkpoint_id)" \
      && [[ "$checkpoint_current" =~ ^[0-9]+$ ]] \
      && (( checkpoint_current > checkpoint_before )); then
    checkpoint=true
    break
  fi
  sleep 2
done
[[ "$checkpoint" == true ]]
dc exec -T --user hadoop secondarynamenode ls -l /data/checkpoint/current > reports/checkpoint.txt
printf 'Checkpoint transaction ID: %s -> %s\n' "$checkpoint_before" "$checkpoint_current" >> reports/checkpoint.txt
echo 'PASS: SecondaryNameNode produced a checkpoint'

dc logs --no-color > reports/cluster.log 2>&1
if grep -E '[[:space:]](ERROR|FATAL)[[:space:]]' reports/cluster.log > reports/critical-errors.txt; then
  cat reports/critical-errors.txt >&2
  exit 1
fi
dc ps > reports/containers.txt
date -u '+%Y-%m-%dT%H:%M:%SZ' > reports/checked-at.txt
echo 'PASS: no ERROR/FATAL records in available container logs'
echo 'PASS: HDFS verification completed; reports saved in reports/'
