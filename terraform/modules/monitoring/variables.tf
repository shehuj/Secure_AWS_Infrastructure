variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "instance_ids" {
  description = "List of EC2 instance IDs to monitor"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "create_sns_topic" {
  description = "Create SNS topic for alarms"
  type        = bool
  default     = true
}

variable "alarm_email_endpoints" {
  description = "List of email addresses to receive alarm notifications"
  type        = list(string)
  default     = []
}

variable "cpu_threshold" {
  description = "CPU utilization threshold for alarms (percentage)"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "Memory utilization threshold for alarms (percentage)"
  type        = number
  default     = 80
}

variable "disk_threshold" {
  description = "Disk utilization threshold for alarms (percentage)"
  type        = number
  default     = 80
}

variable "enable_memory_monitoring" {
  description = "Enable memory monitoring (requires CloudWatch agent)"
  type        = bool
  default     = true
}

variable "enable_disk_monitoring" {
  description = "Enable disk monitoring (requires CloudWatch agent)"
  type        = bool
  default     = true
}

variable "create_dashboard" {
  description = "Create CloudWatch dashboard"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for monitoring resources"
  type        = map(string)
  default     = {}
}
