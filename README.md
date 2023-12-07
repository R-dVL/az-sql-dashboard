# Monitoring
Grafana Azure SQL Dashboard monitoring


## Table of Contents
1. [Dependencies](#Dependencies)
2. [Usage](#Usage)
2. [Configuration](#Configuration)
2. [Run](#Run)


## Dependencies
- [sql_exporter](https://github.com/burningalchemist/sql_exporter).
- Docker.


## Usage
This Docker image is prepared to start an Azure SQL Grafana Dashboard using Prometheus with an exporter.
    1. **Exporter**: Fetch data from Azure SQL Database with collectors, collectors retrieve information with SQL Queries and saves it in `/metrics`.
    2. **Prometheus**: Works with Web Scrapping, it is configured to scrape database info from `/metrics`.
    3. **Grafana**: Shows Azure SQL Database data fetched in a [Dashboard](sql_exporter\examples\azure-sql-mi\grafana-dashboard).


## Configuration
Configuration is attached to containers with Docker Volumes.


### Exporter
Exporter configuration is read from [sql_exporter.yml](https://github.com/burningalchemist/sql_exporter/blob/master/documentation/sql_exporter.yml). Just follow [this examples](https://github.com/burningalchemist/sql_exporter/tree/master/examples) to achieve the desired configuration.

```yml
# Global settings and defaults.
global:
  # Scrape timeouts ensure that:
  #   (i)  scraping completes in reasonable time and
  #   (ii) slow queries are canceled early when the database is already under heavy load
  # Prometheus informs targets of its own scrape timeout (via the "X-Prometheus-Scrape-Timeout-Seconds" request header)
  # so the actual timeout is computed as:
  #   min(scrape_timeout, X-Prometheus-Scrape-Timeout-Seconds - scrape_timeout_offset)
  #
  # If scrape_timeout <= 0, no timeout is set unless Prometheus provides one. The default is 10s.
  scrape_timeout: 10s
  # Subtracted from Prometheus' scrape_timeout to give us some headroom and prevent Prometheus from timing out first.
  #
  # Must be strictly positive. The default is 500ms.
  scrape_timeout_offset: 500ms
  # Minimum interval between collector runs: by default (0s) collectors are executed on every scrape.
  min_interval: 0s
  # Maximum number of open connections to any one target. Metric queries will run concurrently on multiple connections,
  # as will concurrent scrapes.
  #
  # If max_connections <= 0, then there is no limit on the number of open connections. The default is 3.
  max_connections: 3
  # Maximum number of idle connections to any one target. Unless you use very long collection intervals, this should
  # always be the same as max_connections.
  #
  # If max_idle_connections <= 0, no idle connections are retained. The default is 3.
  max_idle_connections: 3

# The target to monitor and the collectors to execute on it.
target:
  # Target name (optional). Setting this field enables extra metrics e.g. `up` and `scrape_duration` with the `target`
  # label that are always returned on a scrape. If set, sql_exporter always returns HTTP 200 with these metrics populated
  name: mssql_database
  # Data source name always has a URI schema that matches the driver name. In some cases (e.g. MySQL)
  # the schema gets dropped or replaced to match the driver expected DSN format.
  data_source_name: 'sqlserver://prom_user:prom_password@dbserver1.example.com:1433'

  # Collectors (referenced by name) to execute on the target.
  collectors: [mssql_standard]

  # In case you need to connect to a backend that only responds to a limited set of commands (e.g. pgbouncer) or
  # a data warehouse you don't want to keep online all the time (due to the extra cost), you might want to disable `ping`
  enable_ping: true

# A collector is a named set of related metrics that are collected together. It can be referenced by name, possibly
# along with other collectors.
#
# Collectors may be defined inline (under `collectors`) or loaded from `collector_files` (one collector per file).
collectors:
  # A collector defining standard metrics for Microsoft SQL Server.
  - collector_name: mssql_standard

    # Similar to global.min_interval, but applies to this collector only.
    #min_interval: 0s

    # A metric is a Prometheus metric with name, type, help text and (optional) additional labels, paired with exactly
    # one query to populate the metric labels and values from.
    #
    # The result columns conceptually fall into two categories:
    #  * zero or more key columns: their values will be directly mapped to labels of the same name;
    #  * one or more value columns:
    #     * if exactly one value column, the column name name is ignored and its value becomes the metric value
    #     * with multiple value columns, a `value_label` must be defined; the column name will populate this label and
    #       the column value will popilate the metric value.
    metrics:
      # The metric name, type and help text, as exported to /metrics.
      - metric_name: mssql_log_growths
        # This is a Prometheus counter (monotonically increasing value).
        type: counter
        help: 'Total number of times the transaction log has been expanded since last restart, per database.'
        # Optional set of labels derived from key columns.
        key_labels:
          # Populated from the `db` column of each row.
          - db
        static_labels:
        # Arbitrary key/value pair
          env: dev
          region: europe
        # This query returns exactly one value per row, in the `counter` column.
        values: [counter]
        query: |
          SELECT rtrim(instance_name) AS db, cntr_value AS counter
          FROM sys.dm_os_performance_counters
          WHERE counter_name = 'Log Growths' AND instance_name <> '_Total'

      # A different metric, with multiple values produced from each result row.
      - metric_name: mssql_io_stall_seconds
        type: counter
        help: 'Stall time in seconds per database and I/O operation.'
        key_labels:
          # Populated from the `db` column of the result.
          - db
        # Label populated with the value column name, configured via `values` (e.g. `operation="io_stall_read_ms"`).
        #
        # Required when multiple value columns are configured.
        value_label: operation
        # Multiple value columns: their name is recorded in the label defined by `attrubute_label` (e.g. 
        # `operation="io_stall_read_ms"`).
        values:
          - io_stall_read
          - io_stall_write
        query_ref: io_stall

      # Another metric, uses same named query (referenced through query_ref) as mssql_io_stall_seconds.
      - metric_name: mssql_io_stall_total_seconds
        type: counter
        help: 'Total stall time in seconds per database.'
        key_labels:
          # Populated from the `db` column of the result.
          - db
        # Only one value, populated from the `io_stall` column.
        values:
          - io_stall
        query_ref: io_stall

      # Metric with a static value to retrieve string data.
      - metric_name: mssql_hostname
        type: gauge
        help: 'Database server hostname'
        key_labels:
          # Populated from the `hostname` column of the result.
          - hostname
        # Static value, always set to `1`.
        static_value: 1
        query: |
          SELECT @@SERVERNAME AS hostname


    # Named queries, referenced by one or more metrics, through query_ref.
    queries:
      # Populates `mssql_io_stall` and `mssql_io_stall_total`
      - query_name: io_stall
        query: |
          SELECT
            cast(DB_Name(a.database_id) as varchar) AS db,
            sum(io_stall_read_ms) / 1000.0 AS io_stall_read,
            sum(io_stall_write_ms) / 1000.0 AS io_stall_write,
            sum(io_stall) / 1000.0 AS io_stall
          FROM
            sys.dm_io_virtual_file_stats(null, null) a
          INNER JOIN sys.master_files b ON a.database_id = b.database_id AND a.file_id = b.file_id
          GROUP BY a.database_id

# Collector files specifies a list of globs. One collector definition per file.
collector_files: 
  - "*.collector.yml"
```

Exporter also use collectors to fetch data from database with SQL queries, this is a standard collector:

```yml
# A collector defining standard metrics for Microsoft SQL Server.
#
# It is required that the SQL Server user has the following permissions:
#
#   GRANT VIEW ANY DEFINITION TO
#   GRANT VIEW SERVER STATE TO
#
collector_name: mssql_standard

# Similar to global.min_interval, but applies to the queries defined by this collector only.
#min_interval: 0s

metrics:
  - metric_name: mssql_local_time_seconds
    type: gauge
    help: 'Local time in seconds since epoch (Unix time).'
    values: [unix_time]
    query: |
      SELECT DATEDIFF(second, '19700101', GETUTCDATE()) AS unix_time

  - metric_name: mssql_connections
    type: gauge
    help: 'Number of active connections.'
    key_labels:
      - db
    values: [count]
    query: |
      SELECT DB_NAME(sp.dbid) AS db, COUNT(sp.spid) AS count
      FROM sys.sysprocesses sp
      GROUP BY DB_NAME(sp.dbid)

  #
  # Collected from sys.dm_os_performance_counters
  #
  - metric_name: mssql_deadlocks
    type: counter
    help: 'Number of lock requests that resulted in a deadlock.'
    values: [cntr_value]
    query: |
      SELECT cntr_value
      FROM sys.dm_os_performance_counters WITH (NOLOCK)
      WHERE counter_name = 'Number of Deadlocks/sec' AND instance_name = '_Total'

  - metric_name: mssql_user_errors
    type: counter
    help: 'Number of user errors.'
    values: [cntr_value]
    query: |
      SELECT cntr_value
      FROM sys.dm_os_performance_counters WITH (NOLOCK)
      WHERE counter_name = 'Errors/sec' AND instance_name = 'User Errors'

  - metric_name: mssql_kill_connection_errors
    type: counter
    help: 'Number of severe errors that caused SQL Server to kill the connection.'
    values: [cntr_value]
    query: |
      SELECT cntr_value
      FROM sys.dm_os_performance_counters WITH (NOLOCK)
      WHERE counter_name = 'Errors/sec' AND instance_name = 'Kill Connection Errors'

  - metric_name: mssql_page_life_expectancy_seconds
    type: gauge
    help: 'The minimum number of seconds a page will stay in the buffer pool on this node without references.'
    values: [cntr_value]
    query: |
      SELECT top(1) cntr_value
      FROM sys.dm_os_performance_counters WITH (NOLOCK)
      WHERE counter_name = 'Page life expectancy'

  - metric_name: mssql_batch_requests
    type: counter
    help: 'Number of command batches received.'
    values: [cntr_value]
    query: |
      SELECT cntr_value
      FROM sys.dm_os_performance_counters WITH (NOLOCK)
      WHERE counter_name = 'Batch Requests/sec'

  - metric_name: mssql_log_growths
    type: counter
    help: 'Number of times the transaction log has been expanded, per database.'
    key_labels:
      - db
    values: [cntr_value]
    query: |
      SELECT rtrim(instance_name) AS db, cntr_value
      FROM sys.dm_os_performance_counters WITH (NOLOCK)
      WHERE counter_name = 'Log Growths' AND instance_name <> '_Total'

  - metric_name: mssql_buffer_cache_hit_ratio
    type: gauge
    help: 'Ratio of requests that hit the buffer cache'
    values: [cntr_value]
    query: |
      SELECT cntr_value
      FROM sys.dm_os_performance_counters
      WHERE [counter_name] = 'Buffer cache hit ratio'

  - metric_name: mssql_checkpoint_pages_sec
    type: gauge
    help: 'Checkpoint Pages Per Second'
    values: [cntr_value]
    query: |
      SELECT cntr_value
      FROM sys.dm_os_performance_counters
      WHERE [counter_name] = 'Checkpoint pages/sec'

  #
  # Collected from sys.dm_io_virtual_file_stats
  #
  - metric_name: mssql_io_stall_seconds
    type: counter
    help: 'Stall time in seconds per database and I/O operation.'
    key_labels:
      - db
    value_label: operation
    values:
      - read
      - write
    query_ref: mssql_io_stall
  - metric_name: mssql_io_stall_total_seconds
    type: counter
    help: 'Total stall time in seconds per database.'
    key_labels:
      - db
    values:
      - io_stall
    query_ref: mssql_io_stall

  #
  # Collected from sys.dm_os_process_memory
  #
  - metric_name: mssql_resident_memory_bytes
    type: gauge
    help: 'SQL Server resident memory size (AKA working set).'
    values: [resident_memory_bytes]
    query_ref: mssql_process_memory

  - metric_name: mssql_virtual_memory_bytes
    type: gauge
    help: 'SQL Server committed virtual memory size.'
    values: [virtual_memory_bytes]
    query_ref: mssql_process_memory

  - metric_name: mssql_memory_utilization_percentage
    type: gauge
    help: 'The percentage of committed memory that is in the working set.'
    values: [memory_utilization_percentage]
    query_ref: mssql_process_memory

  - metric_name: mssql_page_fault_count
    type: counter
    help: 'The number of page faults that were incurred by the SQL Server process.'
    values: [page_fault_count]
    query_ref: mssql_process_memory

  #
  # Collected from sys.dm_os_sys_memory
  #
  - metric_name: mssql_os_memory
    type: gauge
    help: 'OS physical memory, used and available.'
    value_label: 'state'
    values: [used, available]
    query: |
      SELECT
        (total_physical_memory_kb - available_physical_memory_kb) * 1024 AS used,
        available_physical_memory_kb * 1024 AS available
      FROM sys.dm_os_sys_memory

  - metric_name: mssql_os_page_file
    type: gauge
    help: 'OS page file, used and available.'
    value_label: 'state'
    values: [used, available]
    query: |
      SELECT
        (total_page_file_kb - available_page_file_kb) * 1024 AS used,
        available_page_file_kb * 1024 AS available
      FROM sys.dm_os_sys_memory

queries:
  # Populates `mssql_io_stall` and `mssql_io_stall_total`
  - query_name: mssql_io_stall
    query: |
      SELECT
        cast(DB_Name(a.database_id) as varchar) AS [db],
        sum(io_stall_read_ms) / 1000.0 AS [read],
        sum(io_stall_write_ms) / 1000.0 AS [write],
        sum(io_stall) / 1000.0 AS io_stall
      FROM
        sys.dm_io_virtual_file_stats(null, null) a
      INNER JOIN sys.master_files b ON a.database_id = b.database_id AND a.file_id = b.file_id
      GROUP BY a.database_id

  # Populates `mssql_resident_memory_bytes`, `mssql_virtual_memory_bytes`, `mssql_memory_utilization_percentage` and
  # `mssql_page_fault_count`.
  - query_name: mssql_process_memory
    query: |
      SELECT
        physical_memory_in_use_kb * 1024 AS resident_memory_bytes,
        virtual_address_space_committed_kb * 1024 AS virtual_memory_bytes,
        memory_utilization_percentage,
        page_fault_count
      FROM sys.dm_os_process_memory
```

### Prometheus
Prometheus is configured to scrape data from `http://localhost:9399/metrics` where Exporter is showing data fetched, its configuration file is also attached to its Docker Container with a volume and this is an example:

```yml
global:
  scrape_interval:     15s 
  evaluation_interval: 15s 

scrape_configs:
  - job_name: 'azure_sql_database'
    static_configs:
      - targets: ['localhost:9399'] 
    metrics_path: /metrics
```

### Grafana
Grafana is configured using its own GUI, just stablish a connection with Prometheus and import or create a [Dashboard](sql_exporter\examples\azure-sql-mi\grafana-dashboard).


## Run
You can start these 3 services using the Docker Compose file in this repo `docker compose up -d`.

```yml
version: '3'

services:
  exporter:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: exporter
    volumes:
      - ./config/sql_exporter:/config
    ports:
      - 9399:9399

  prometheus:
    image: prom/prometheus
    container_name: prometheus
    volumes:
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - 9090:9090

  grafana:
    image: grafana/grafana
    container_name: grafana
    ports:
      - 3000:3000
```

This `docker-compose.yml` will build the _sql_exporter_ binaries and start three containers, **Grafana**, **Prometheus** and **Exporter**.

In this case I'm attaching a config folder to **Exporter** and `prometheus.yml` to **Prometheus**, this is the folder structure used in the example:

```text
(root)
+- config                                   # Config folder
|   +- prometheus
|       +- prometheus.yml
|   +- sql_exporter
|       +- sql_exporter.yml
|       +- mssql_mi_perf.collector.yml
|       +- ...                              # Other collectors used
+- sql_exporter                             # Exporter source code
|   +- ...
+- Dockerfile
+- docker-compose.yml
```

