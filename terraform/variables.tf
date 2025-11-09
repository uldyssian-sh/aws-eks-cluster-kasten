# Variables for AWS EKS Cluster with Kasten K10

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "kasten-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "platform-team"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# Node Group Configuration
variable "node_instance_types" {
  description = "Instance types for EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "Capacity type for node group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in node group"
  type        = number
  default     = 1
  
  validation {
    condition     = var.node_group_min_size >= 1 && var.node_group_min_size <= 10
    error_message = "Node group minimum size must be between 1 and 10."
  }
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in node group"
  type        = number
  default     = 5
  
  validation {
    condition     = var.node_group_max_size >= 1 && var.node_group_max_size <= 20
    error_message = "Node group maximum size must be between 1 and 20."
  }
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in node group"
  type        = number
  default     = 3
  
  validation {
    condition     = var.node_group_desired_size >= 1 && var.node_group_desired_size <= 20
    error_message = "Node group desired size must be between 1 and 20."
  }
}

variable "node_disk_size" {
  description = "Disk size for worker nodes (GB)"
  type        = number
  default     = 50
}

# Kasten Configuration
variable "kasten_namespace" {
  description = "Kubernetes namespace for Kasten K10"
  type        = string
  default     = "kasten-io"
}

variable "kasten_chart_version" {
  description = "Helm chart version for Kasten K10"
  type        = string
  default     = "6.5.0"
}

variable "enable_kasten_dashboard" {
  description = "Enable external access to Kasten dashboard"
  type        = bool
  default     = true
}

# Backup Configuration
variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

variable "backup_schedule" {
  description = "Cron schedule for automated backups"
  type        = string
  default     = "0 2 * * *" # Daily at 2 AM
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Kasten dashboard"
  type        = list(string)
  default     = ["10.0.0.0/8"] # Restrict to private networks by default
  validation {
    condition     = length(var.allowed_cidr_blocks) > 0
    error_message = "At least one CIDR block must be specified."
  }
}

variable "enable_encryption" {
  description = "Enable encryption for EBS volumes and S3 bucket"
  type        = bool
  default     = true
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Enable monitoring stack (Prometheus, Grafana)"
  type        = bool
  default     = false
}

variable "enable_logging" {
  description = "Enable centralized logging (ELK stack)"
  type        = bool
  default     = false
}# Updated 20251109_123800
# Updated Sun Nov  9 12:52:16 CET 2025
