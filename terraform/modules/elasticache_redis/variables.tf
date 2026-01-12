# ElastiCache Redis Module Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Redis will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Redis subnet group (private subnets recommended)"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "List of security group IDs allowed to access Redis"
  type        = list(string)
}

variable "redis_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_family" {
  description = "Redis parameter group family"
  type        = string
  default     = "redis7"
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro" # 0.5 GB RAM - good for sessions/caching
}

variable "num_cache_nodes" {
  description = "Number of cache nodes (1 for single node, 2+ for cluster with replication)"
  type        = number
  default     = 2
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ for automatic failover"
  type        = bool
  default     = true
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)"
  type        = string
  default     = "sun:05:00-sun:06:00" # Sunday 5-6 AM UTC
}

variable "snapshot_window" {
  description = "Daily snapshot window (UTC)"
  type        = string
  default     = "04:00-05:00" # 4-5 AM UTC
}

variable "snapshot_retention_limit" {
  description = "Number of days to retain automatic snapshots"
  type        = number
  default     = 5
}

variable "transit_encryption_enabled" {
  description = "Enable encryption in transit (requires auth token)"
  type        = bool
  default     = true
}

variable "auto_minor_version_upgrade" {
  description = "Auto upgrade to minor versions"
  type        = bool
  default     = true
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for ElastiCache notifications"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
