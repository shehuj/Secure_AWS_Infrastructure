global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: '${ecs_cluster_name}'
    region: '${region}'

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # ECS Service Discovery for Ghost application
  - job_name: 'ecs-ghost'
    ec2_sd_configs:
      - region: ${region}
        port: 9090
        filters:
          - name: 'tag:aws:ecs:clusterName'
            values: ['${ecs_cluster_name}']
          - name: 'tag:aws:ecs:serviceName'
            values: ['${ghost_service_name}']

    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: '$1:2368'

  # ECS Task Metadata Endpoint (for container metrics)
  - job_name: 'ecs-tasks'
    ec2_sd_configs:
      - region: ${region}
        port: 51678
        filters:
          - name: 'tag:aws:ecs:clusterName'
            values: ['${ecs_cluster_name}']

    relabel_configs:
      - source_labels: [__meta_ec2_tag_aws_ecs_task_family]
        target_label: task_family
      - source_labels: [__meta_ec2_tag_aws_ecs_cluster_name]
        target_label: cluster
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: '$1:51678'
      - source_labels: []
        target_label: __metrics_path__
        replacement: '/task/stats'

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files:
  # - "alerts/*.yml"
