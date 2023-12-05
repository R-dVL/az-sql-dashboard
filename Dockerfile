ARG  ARCH="amd64"
ARG  OS="linux"
FROM quay.io/prometheus/golang-builder AS builder

# Get sql_exporter
ADD .   /sql_exporter
WORKDIR /sql_exporter

# Do makefile
RUN make

# Make image and copy build sql_exporter
FROM        quay.io/prometheus/busybox-${OS}-${ARCH}:latest
LABEL       maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"
COPY        --from=builder /sql_exporter/sql_exporter  /bin/sql_exporter

EXPOSE      9399
USER        nobody
ENTRYPOINT  [ "/bin/sql_exporter" ]