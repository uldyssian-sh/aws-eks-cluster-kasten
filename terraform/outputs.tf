# Outputs for AWS EKS Cluster with Kasten K10

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks.cluster_primary_security_group_id
}

output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "node_groups" {
  description = "EKS node groups"
  value       = module.eks.eks_managed_node_groups
}

output "node_security_group_id" {
  description = "ID of the node shared security group"
  value       = module.eks.node_security_group_id
}

# Kasten-specific outputs
output "kasten_s3_bucket_name" {
  description = "Name of S3 bucket for Kasten backups"
  value       = aws_s3_bucket.kasten_backups.bucket
}

output "kasten_s3_bucket_arn" {
  description = "ARN of S3 bucket for Kasten backups"
  value       = aws_s3_bucket.kasten_backups.arn
}

output "kasten_iam_role_arn" {
  description = "ARN of IAM role for Kasten K10"
  value       = aws_iam_role.kasten_role.arn
}

output "kasten_iam_role_name" {
  description = "Name of IAM role for Kasten K10"
  value       = aws_iam_role.kasten_role.name
}

# Connection information
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "cluster_info" {
  description = "Cluster connection information"
  value = {
    cluster_name = var.cluster_name
    region       = var.aws_region
    endpoint     = module.eks.cluster_endpoint
    version      = var.kubernetes_version
  }
}

# Cost estimation (WARNING: Pricing is approximate and based on us-west-2 region as of 2024)
# Please verify current AWS pricing at https://calculator.aws for accurate estimates
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD) - prices may vary by region and time"
  value = {
    eks_control_plane = "73.00"                                                      # EKS cluster cost
    worker_nodes      = "${var.node_group_desired_size * 31.00}"                     # t3.medium pricing
    ebs_storage       = "${var.node_group_desired_size * var.node_disk_size * 0.10}" # gp3 storage
    load_balancer     = "22.00"                                                      # ALB cost
    total_estimated   = "${73 + (var.node_group_desired_size * 31) + (var.node_group_desired_size * var.node_disk_size * 0.10) + 22}"
    note              = "Prices are estimates based on us-west-2 region. Use AWS Pricing Calculator for accurate costs."
  }
}# Updated 20251109_123800
