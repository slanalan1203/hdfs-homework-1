FROM eclipse-temurin:11-jdk-jammy

ARG TARGETARCH
ENV HADOOP_HOME=/opt/hadoop \
    HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop \
    HADOOP_LOG_DIR=/opt/hadoop/logs \
    HADOOP_HEAPSIZE_MAX=512 \
    PATH=/opt/hadoop/bin:/opt/hadoop/sbin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates gosu tini python3 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 hadoop && useradd --uid 1000 --gid hadoop --create-home hadoop

# SHA-512 values published by Apache for the pinned 3.4.3 release.
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) archive=hadoop-3.4.3.tar.gz; checksum=e25be7e57b4d3c5bfe83895844321a21d6cf7331266d524d8983c27cf484e576c3d79b3b60d590f8cddecf16229d0e232de2491b1b61b362ee7d67072c7290e1 ;; \
      arm64) archive=hadoop-3.4.3-aarch64.tar.gz; checksum=2f5c1719b801eedecc5bbed0d4c6d61d7c4850dbb5944fb79da24474f694cb5d0f00b07d1b54cade83f6ca492e1697225f47737cc1a4478ca04102062cf314d5 ;; \
      *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    (curl --fail --location --retry 5 --connect-timeout 20 "https://dlcdn.apache.org/hadoop/common/hadoop-3.4.3/$archive" -o /tmp/hadoop.tar.gz \
      || curl --fail --location --retry 5 --connect-timeout 20 "https://archive.apache.org/dist/hadoop/common/hadoop-3.4.3/$archive" -o /tmp/hadoop.tar.gz); \
    printf '%s  /tmp/hadoop.tar.gz\n' "$checksum" | sha512sum -c -; \
    tar -xzf /tmp/hadoop.tar.gz -C /opt; \
    mv /opt/hadoop-3.4.3 /opt/hadoop; \
    rm /tmp/hadoop.tar.gz; \
    mkdir -p /data /opt/hadoop/logs; \
    chown -R hadoop:hadoop /data /opt/hadoop/logs

COPY config/core-site.xml config/hdfs-site.xml /opt/hadoop/etc/hadoop/
COPY docker/entrypoint.sh /usr/local/bin/hdfs-entrypoint
COPY scripts/check-nodes.py /usr/local/bin/check-nodes.py
RUN chmod 755 /usr/local/bin/hdfs-entrypoint
WORKDIR /opt/hadoop
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/hdfs-entrypoint"]
