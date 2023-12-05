# Usar una imagen base de Ubuntu
FROM ubuntu:latest

# Instalar dependencias necesarias
RUN apt-get update && apt-get install -y \
    wget \
    tar

# Descargar e instalar Grafana
RUN wget https://dl.grafana.com/oss/release/grafana-8.3.3.linux-amd64.tar.gz \
    && tar -zxvf grafana-8.3.3.linux-amd64.tar.gz \
    && rm grafana-8.3.3.linux-amd64.tar.gz

# Descargar e instalar Prometheus
RUN wget https://github.com/prometheus/prometheus/releases/download/v2.31.1/prometheus-2.31.1.linux-amd64.tar.gz \
    && tar xvf prometheus-2.31.1.linux-amd64.tar.gz \
    && rm prometheus-2.31.1.linux-amd64.tar.gz

# Copiar el archivo de configuración de Prometheus en el contenedor
COPY ./prometheus.yml /prometheus-2.31.1.linux-amd64/

# Establecer el directorio de trabajo
WORKDIR /grafana-8.3.3

# Exponer los puertos de Grafana y Prometheus
EXPOSE 3000 9090

# Iniciar Grafana y Prometheus
CMD ./bin/grafana-server & /prometheus-2.31.1.linux-amd64/prometheus --config.file=/prometheus-2.31.1.linux-amd64/prometheus.yml