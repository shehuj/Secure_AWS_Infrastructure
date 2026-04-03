# RDS MySQL Module Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for RDS subnet group (private subnets recommended)"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to reach RDS on port 3306 (e.g. VPC CIDR)"
  type        = list(string)
}

variable "mysql_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small" # 2 vCPU, 2 GB RAM - good for production Ghost
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "iops" {
  description = "Provisioned IOPS for gp3 storage"
  type        = number
  default     = 3000
}

variable "database_name" {
  description = "Name of the default database"
  type        = string
  default     = "ghost"
}

variable "master_username" {
  description = "Master username for RDS (used by Ansible for DB provisioning)"
  type        = string
  default     = "ghostadmin"
}

variable "app_username" {
  description = "Restricted application username created by Ansible (used by Ghost ECS)"
  type        = string
  default     = "ghost_app"
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = true
}

variable "availability_zone" {
  description = "AZ for single-AZ deployment (only used if multi_az = false)"
  type        = string
  default     = null
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Daily backup window (UTC)"
  type        = string
  default     = "03:00-04:00" # 3-4 AM UTC
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00" # Sunday 4-5 AM UTC
}

variable "enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 60
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "final_snapshot_enabled" {
  description = "Create final snapshot on deletion"
  type        = bool
  default     = true
}

variable "auto_minor_version_upgrade" {
  description = "Auto upgrade to minor versions"
  type        = bool
  default     = true
}

variable "max_connections" {
  description = "Maximum number of database connections"
  type        = number
  default     = 100
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
