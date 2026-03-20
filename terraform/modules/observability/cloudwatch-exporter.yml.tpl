region: ${region}

metrics:
  # ── ECS ────────────────────────────────────────────────────────────────────
  - aws_namespace: AWS/ECS
    aws_metric_name: CPUUtilization
    aws_dimensions: [ClusterName, ServiceName]
    aws_statistics: [Average, Maximum]
    range_seconds: 300

  - aws_namespace: AWS/ECS
    aws_metric_name: MemoryUtilization
    aws_dimensions: [ClusterName, ServiceName]
    aws_statistics: [Average, Maximum]
    range_seconds: 300

  # ── ALB ────────────────────────────────────────────────────────────────────
  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: RequestCount
    aws_dimensions: [LoadBalancer]
    aws_statistics: [Sum]
    range_seconds: 60

  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: TargetResponseTime
    aws_dimensions: [LoadBalancer]
    aws_statistics: [Average, p99]
    range_seconds: 60

  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: HTTPCode_Target_5XX_Count
    aws_dimensions: [LoadBalancer]
    aws_statistics: [Sum]
    range_seconds: 60

  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: HTTPCode_Target_4XX_Count
    aws_dimensions: [LoadBalancer]
    aws_statistics: [Sum]
    range_seconds: 60

  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: HealthyHostCount
    aws_dimensions: [TargetGroup, LoadBalancer]
    aws_statistics: [Minimum]
    range_seconds: 60

  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: UnHealthyHostCount
    aws_dimensions: [TargetGroup, LoadBalancer]
    aws_statistics: [Maximum]
    range_seconds: 60

  # ── RDS ────────────────────────────────────────────────────────────────────
  - aws_namespace: AWS/RDS
    aws_metric_name: CPUUtilization
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Maximum]
    range_seconds: 300

  - aws_namespace: AWS/RDS
    aws_metric_name: FreeStorageSpace
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Minimum]
    range_seconds: 300

  - aws_namespace: AWS/RDS
    aws_metric_name: FreeableMemory
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Minimum]
    range_seconds: 300

  - aws_namespace: AWS/RDS
    aws_metric_name: DatabaseConnections
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average, Maximum]
    range_seconds: 60

  - aws_namespace: AWS/RDS
    aws_metric_name: ReadLatency
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]
    range_seconds: 60

  - aws_namespace: AWS/RDS
    aws_metric_name: WriteLatency
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]
    range_seconds: 60
