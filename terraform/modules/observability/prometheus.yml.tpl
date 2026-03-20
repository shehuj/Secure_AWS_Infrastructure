global:
  scrape_interval:     15s
  evaluation_interval: 15s
  external_labels:
    cluster: '${ecs_cluster_name}'
    region:  '${region}'

scrape_configs:

  # ── Prometheus self-monitoring ──────────────────────────────────────────────
  # Always works — confirms Prometheus itself is healthy.
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # ── ECS Fargate service discovery (all tasks in cluster) ───────────────────
  # Uses ecs_sd_configs — the correct SD method for Fargate.
  # ec2_sd_configs does NOT work with Fargate (no underlying EC2 to query).
  - job_name: 'ecs-fargate'
    ecs_sd_configs:
      - region: ${region}

    relabel_configs:
      # Only keep tasks in our cluster
      - source_labels: [__meta_ecs_cluster_arn]
        regex:  '.*${ecs_cluster_name}.*'
        action: keep

      # Drop tasks that have no service name (one-off tasks, migrations, etc.)
      - source_labels: [__meta_ecs_service_name]
        regex:  '.+'
        action: keep

      # Expose useful labels in Grafana
      - source_labels: [__meta_ecs_service_name]
        target_label: service
      - source_labels: [__meta_ecs_container_name]
        target_label: container
      - source_labels: [__meta_ecs_task_definition_family]
        target_label: task_family
      - source_labels: [__meta_ecs_task_health_status]
        target_label: health

  # ── Ghost application (ECS Fargate) ────────────────────────────────────────
  # Ghost CMS does not expose Prometheus metrics natively.
  # This job scrapes Ghost's built-in status endpoint and converts HTTP
  # availability into an up/down probe that Grafana can alert on.
  # To get full application metrics, add a metrics exporter sidecar.
  - job_name: 'ghost-probe'
    metrics_path: /ghost/api/v4/admin/site/
    scheme: http
    ecs_sd_configs:
      - region: ${region}

    relabel_configs:
      # Keep only the Ghost service
      - source_labels: [__meta_ecs_service_name]
        regex:  '.*${ghost_service_name}.*'
        action: keep

      # Point to Ghost's HTTP port
      - source_labels: [__address__]
        regex:  '([^:]+)(?::\d+)?'
        replacement: '$1:2368'
        target_label: __address__

      - source_labels: [__meta_ecs_service_name]
        target_label: service
      - source_labels: [__meta_ecs_task_definition_family]
        target_label: task_family

  # ── Node Exporter (ECS Fargate) ────────────────────────────────────────────
  # Exposes container-level CPU, memory and network metrics.
  # Runs as a standalone ECS service on port 9100.
  - job_name: 'node'
    ecs_sd_configs:
      - region: ${region}

    relabel_configs:
      - source_labels: [__meta_ecs_service_name]
        regex:  '.*node-exporter.*'
        action: keep

      - source_labels: [__address__]
        regex:  '([^:]+)(?::\d+)?'
        replacement: '$1:9100'
        target_label: __address__

      - source_labels: [__meta_ecs_service_name]
        target_label: service
      - source_labels: [__meta_ecs_task_definition_family]
        target_label: task_family

  # ── MySQL Exporter ──────────────────────────────────────────────────────────
  # Exposes RDS MySQL metrics (connections, query latency, InnoDB stats).
  # Runs as a standalone ECS service on port 9104.
  - job_name: 'mysql'
    ecs_sd_configs:
      - region: ${region}

    relabel_configs:
      - source_labels: [__meta_ecs_service_name]
        regex:  '.*mysql-exporter.*'
        action: keep

      - source_labels: [__address__]
        regex:  '([^:]+)(?::\d+)?'
        replacement: '$1:9104'
        target_label: __address__

      - source_labels: [__meta_ecs_service_name]
        target_label: service
      - source_labels: [__meta_ecs_task_definition_family]
        target_label: task_family

  # ── CloudWatch Exporter ─────────────────────────────────────────────────────
  # Exposes AWS CloudWatch metrics (ECS, ALB, RDS) to Prometheus.
  # Runs as a sidecar in the Prometheus task on port 9106.
  # See: https://github.com/prometheus/cloudwatch_exporter
  - job_name: 'cloudwatch'
    static_configs:
      - targets: ['localhost:9106']

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files:
  # - "alerts/*.yml"
