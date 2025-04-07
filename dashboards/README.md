# Grafana Dashboard Collection

This folder contains a collection of pre-built Grafana dashboards using Prometheus as the data source.

## Dashboards Overview

| Filename                     | Dashboard Type     | Description                                                                                                                                         | Panels Count | Data Source |
|-----------------------------|--------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|--------------|-------------|
| `jvm-dashboard-basic.json`  | JVM (Basic)        | A lightweight dashboard providing a general overview of JVM performance. It includes panels for heap/non-heap memory usage, thread counts, and GC activity. Designed for simple monitoring setups. | 6            | Prometheus  |
| `jvm-dashboard-advanced.json` | JVM (Advanced)   | A comprehensive dashboard for in-depth JVM performance monitoring. Features include detailed GC metrics (pause time, count), memory pools, class loading, CPU usage, and thread states, aimed at production-grade observability. | 13           | Prometheus  |
| `nodejs-dashboard-advanced.json` | Node.js (Advanced) | A detailed dashboard focused on Node.js application internals. Includes charts for event loop lag, heap usage, external memory, CPU usage, Node.js version breakdown, and process restarts. Useful for performance tuning and troubleshooting. | 6+           | Prometheus  |

## Requirements

- Prometheus data source configured
- Exporters providing metrics (e.g., `jmx_exporter`, `prom-client`)

