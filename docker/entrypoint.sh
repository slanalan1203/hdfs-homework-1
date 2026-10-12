#!/usr/bin/env bash
set -euo pipefail
role="${1:-}"
case "$role" in
  namenode|secondarynamenode|datanode) ;;
  *) echo 'Expected role: namenode, secondarynamenode or datanode' >&2; exit 2 ;;
esac
if [[ "$(id -u)" == 0 ]]; then
  mkdir -p /data "$HADOOP_LOG_DIR"
  chown -R hadoop:hadoop /data "$HADOOP_LOG_DIR"
  exec gosu hadoop "$0" "$role"
fi
if [[ "$role" == namenode && ! -f /data/name/current/VERSION ]]; then
  if [[ -d /data/name && -n "$(find /data/name -mindepth 1 -print -quit)" ]]; then
    echo 'Refusing to format nonempty NameNode storage without VERSION.' >&2
    exit 1
  fi
  hdfs namenode -format -nonInteractive
fi
exec hdfs "$role"
