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
    aws_metric_name: HTTPCode_ELB_5XX_Count
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

  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: ActiveConnectionCount
    aws_dimensions: [LoadBalancer]
    aws_statistics: [Sum]
    range_seconds: 60

  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: ProcessedBytes
    aws_dimensions: [LoadBalancer]
    aws_statistics: [Sum]
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

  - aws_namespace: AWS/RDS
    aws_metric_name: ReadIOPS
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]
    range_seconds: 60

  - aws_namespace: AWS/RDS
    aws_metric_name: WriteIOPS
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]
    range_seconds: 60

  - aws_namespace: AWS/RDS
    aws_metric_name: NetworkReceiveThroughput
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]
    range_seconds: 300

  - aws_namespace: AWS/RDS
    aws_metric_name: NetworkTransmitThroughput
    aws_dimensions: [DBInstanceIdentifier]
    aws_statistics: [Average]
    range_seconds: 300

  # ── EC2 / Auto Scaling Group ────────────────────────────────────────────────
  - aws_namespace: AWS/EC2
    aws_metric_name: CPUUtilization
    aws_dimensions: [AutoScalingGroupName]
    aws_statistics: [Average, Maximum]
    range_seconds: 300

  - aws_namespace: AWS/EC2
    aws_metric_name: NetworkIn
    aws_dimensions: [AutoScalingGroupName]
    aws_statistics: [Average, Sum]
    range_seconds: 300

  - aws_namespace: AWS/EC2
    aws_metric_name: NetworkOut
    aws_dimensions: [AutoScalingGroupName]
    aws_statistics: [Average, Sum]
    range_seconds: 300

  - aws_namespace: AWS/EC2
    aws_metric_name: StatusCheckFailed
    aws_dimensions: [AutoScalingGroupName]
    aws_statistics: [Sum]
    range_seconds: 300

  - aws_namespace: AWS/AutoScaling
    aws_metric_name: GroupInServiceInstances
    aws_dimensions: [AutoScalingGroupName]
    aws_statistics: [Average, Minimum]
    range_seconds: 60

  - aws_namespace: AWS/AutoScaling
    aws_metric_name: GroupDesiredCapacity
    aws_dimensions: [AutoScalingGroupName]
    aws_statistics: [Average]
    range_seconds: 60

  - aws_namespace: AWS/AutoScaling
    aws_metric_name: GroupTotalInstances
    aws_dimensions: [AutoScalingGroupName]
    aws_statistics: [Average]
    range_seconds: 60

  # ── EFS ─────────────────────────────────────────────────────────────────────
  - aws_namespace: AWS/EFS
    aws_metric_name: BurstCreditBalance
    aws_dimensions: [FileSystemId]
    aws_statistics: [Minimum]
    range_seconds: 300

  - aws_namespace: AWS/EFS
    aws_metric_name: PercentIOLimit
    aws_dimensions: [FileSystemId]
    aws_statistics: [Average, Maximum]
    range_seconds: 300

  - aws_namespace: AWS/EFS
    aws_metric_name: DataReadIOBytes
    aws_dimensions: [FileSystemId]
    aws_statistics: [Sum, Average]
    range_seconds: 300

  - aws_namespace: AWS/EFS
    aws_metric_name: DataWriteIOBytes
    aws_dimensions: [FileSystemId]
    aws_statistics: [Sum, Average]
    range_seconds: 300

  - aws_namespace: AWS/EFS
    aws_metric_name: ClientConnections
    aws_dimensions: [FileSystemId]
    aws_statistics: [Sum]
    range_seconds: 60

  # ── NAT Gateway ─────────────────────────────────────────────────────────────
  - aws_namespace: AWS/NATGateway
    aws_metric_name: BytesInFromDestination
    aws_dimensions: [NatGatewayId]
    aws_statistics: [Sum]
    range_seconds: 300

  - aws_namespace: AWS/NATGateway
    aws_metric_name: BytesOutToDestination
    aws_dimensions: [NatGatewayId]
    aws_statistics: [Sum]
    range_seconds: 300

  - aws_namespace: AWS/NATGateway
    aws_metric_name: PacketsDropCount
    aws_dimensions: [NatGatewayId]
    aws_statistics: [Sum]
    range_seconds: 300

  - aws_namespace: AWS/NATGateway
    aws_metric_name: ErrorPortAllocation
    aws_dimensions: [NatGatewayId]
    aws_statistics: [Sum]
    range_seconds: 300
