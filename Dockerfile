ARG  ARCH="amd64"
ARG  OS="linux"

# Build sql_exporter binaries
FROM quay.io/prometheus/golang-builder AS builder

# Get sql_exporter
ADD ./sql_exporter /sql_exporter
WORKDIR /sql_exporter

# Do makefile
RUN make

# Build image and copy build sql_exporter
FROM        quay.io/prometheus/busybox-${OS}-${ARCH}:latest
LABEL       maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"
COPY        --from=builder /sql_exporter/sql_exporter  /bin/sql_exporter

EXPOSE      9399
USER        nobody

# Map local volume with sql_exporter.yml and collectors to container's /config
ENTRYPOINT  [ "/bin/sql_exporter", "-config.file=/config/sql_exporter.yml"]