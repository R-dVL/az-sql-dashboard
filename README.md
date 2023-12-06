# Monitoring
Grafana Azure SQL Dashboard monitoring


## Table of Contents
1. [Dependencies](#Dependencies)
2. [Usage](#Usage)


## Dependencies
- [sql_exporter](https://github.com/burningalchemist/sql_exporter)
- Docker


## Usage
This Docker image is prepared to start an Azure SQL Grafana Dashboard using Prometheus.


### Config
Prometheus configuration is read from [sql_exporter.yml](https://github.com/burningalchemist/sql_exporter/blob/master/documentation/sql_exporter.yml), where you can define also collectors. Just follow [this examples](https://github.com/burningalchemist/sql_exporter/tree/master/examples) to achieve the desired configuration.

Docker container will read your configuration from your local config folder, just mount your config folder with container's `/config`.


### Run
Docker run will use `-p` and `-v` flags to define host ports and config folder:

```bash
docker run -d -p 9399:9399 -p 8000:8000 -v /your/path/to/config:/config --name=monitoring ghcr.io/r-dvl/monitoring/monitoring
```

