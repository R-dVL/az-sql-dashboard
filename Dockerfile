ARG ARCH="amd64"
ARG OS="linux"

# Build sql_exporter binaries
FROM quay.io/prometheus/golang-builder AS builder

# Get sql_exporter
ADD ./sql_exporter /sql_exporter
WORKDIR /sql_exporter

# Do makefile
RUN make

# Instalar Grafana
FROM grafana/grafana:latest AS grafana

# Copiar el sql_exporter desde el builder
COPY --from=builder /sql_exporter/sql_exporter  /bin/sql_exporter

# Exponer el puerto de Grafana (3000) y sql_exporter (9399)
EXPOSE 3000 9399

# Configurar el usuario
USER grafana

# Iniciar Grafana y sql_exporter
ENTRYPOINT grafana-server & /bin/sql_exporter -config.file=/config/sql_exporter.yml