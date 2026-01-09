variable "vpc_id" {
  description = "VPC ID where EC2 instances will be launched"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EC2 instances"
  type        = list(string)
}

variable "key_pair" {
  description = "SSH key pair name for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (if empty, will use latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "instance_count" {
  description = "Number of EC2 instances to launch"
  type        = number
  default     = 1
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to SSH to instances"
  type        = list(string)
  default     = []
}

variable "allowed_http_cidr" {
  description = "CIDR blocks allowed HTTP access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_cidr" {
  description = "CIDR blocks allowed HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_public_ip" {
  description = "Associate public IP with instances"
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type of root volume"
  type        = string
  default     = "gp3"
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "create_iam_instance_profile" {
  description = "Create IAM instance profile for EC2"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for EC2 resources"
  type        = map(string)
  default     = {}
}
