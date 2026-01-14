variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Domain name of the Ghost blog"
  type        = string
}

variable "rum_sample_rate" {
  description = "Percentage of sessions to monitor (0.0 to 1.0)"
  type        = number
  default     = 1.0 # 100% sampling
}

variable "favorite_pages" {
  description = "List of favorite pages to monitor"
  type        = list(string)
  default     = ["/", "/about", "/contact"]
}

variable "excluded_pages" {
  description = "List of pages to exclude from monitoring"
  type        = list(string)
  default     = ["/ghost/*", "/admin/*", "*/preview/*"]
}

variable "included_pages" {
  description = "List of pages to specifically include in monitoring"
  type        = list(string)
  default     = ["*"]
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 90
}

variable "alb_log_retention_days" {
  description = "Number of days to retain ALB access logs in S3"
  type        = number
  default     = 90
}

variable "low_traffic_threshold" {
  description = "Minimum unique visitors per hour before alerting"
  type        = number
  default     = 10
}

variable "high_error_threshold" {
  description = "Maximum JavaScript errors before alerting"
  type        = number
  default     = 50
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
