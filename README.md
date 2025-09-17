# AWS EKS Infrastructure

[![CI](https://github.com/uldyssian-sh/REPO_NAME/workflows/CI/badge.svg)](https://github.com/uldyssian-sh/REPO_NAME/actions)
[![Terraform](https://img.shields.io/badge/Terraform-1.0+-blue.svg)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-orange.svg)](https://aws.amazon.com/eks/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

Production-ready AWS EKS cluster automation with Terraform, featuring security best practices and monitoring.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   VPC/Subnets   │────│   EKS Cluster   │────│   Worker Nodes  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Monitoring    │
                    └─────────────────┘
```

## Features

- 🏗️ **Infrastructure as Code**: Terraform modules
- 🔐 **Security**: IAM roles, security groups, encryption
- 📊 **Monitoring**: CloudWatch, Prometheus, Grafana
- 🚀 **Auto-scaling**: Cluster and pod autoscaling
- 🔄 **CI/CD Ready**: GitHub Actions integration

## Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- kubectl
- Helm

## Quick Start

```bash
# Clone and setup
git clone https://github.com/uldyssian-sh/REPO_NAME.git
cd REPO_NAME

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy cluster
terraform apply
```

## Configuration

```hcl
module "eks" {
  source = "./terraform"
  
  cluster_name    = "production-eks"
  cluster_version = "1.28"
  
  vpc_cidr = "10.0.0.0/16"
  
  node_groups = {
    main = {
      instance_types = ["t3.medium"]
      min_size      = 1
      max_size      = 10
      desired_size  = 3
    }
  }
}
```

## Documentation

- [Architecture Guide](docs/architecture.md)
- [Deployment Guide](docs/deployment.md)
- [Monitoring Setup](docs/monitoring.md)
- [Security Hardening](docs/security.md)

## Monitoring

Access monitoring dashboards:
- Grafana: `kubectl port-forward svc/grafana 3000:80`
- Prometheus: `kubectl port-forward svc/prometheus 9090:9090`

## License

MIT License - see [LICENSE](LICENSE) file for details.
