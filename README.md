# AWS EKS Cluster with Kasten K10 Backup Solution

## Table of Contents
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Examples](#examples)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)

## Prerequisites

Before using this project, ensure you have:
- Required tools and dependencies
- Proper access credentials
- System requirements met


[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![AWS](https://img.shields.io/badge/AWS-EKS%20%7C%20S3%20%7C%20IAM-orange)](https://aws.amazon.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-blue)](https://kubernetes.io/)
[![Kasten](https://img.shields.io/badge/Kasten-K10%206.5-green)](https://www.kasten.io/)
[![Terraform](https://img.shields.io/badge/Terraform-1.6%2B-purple)](https://www.terraform.io/)
[![CI](https://github.com/uldyssian-sh/aws-eks-cluster-kasten/actions/workflows/ci.yml/badge.svg)](https://github.com/uldyssian-sh/aws-eks-cluster-kasten/actions/workflows/ci.yml)

A comprehensive **Infrastructure as Code** solution for deploying production-ready Amazon EKS clusters with **Kasten K10 data protection platform**.
This repository provides both **shell scripts** and **Terraform modules** for automated deployment, backup, and disaster recovery on AWS.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        AWS EKS + Kasten K10 Architecture                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┬─────────────────┬─────────────────────────────────────┐    │
│  │   AZ-A          │   AZ-B          │   AZ-C                              │    │
│  │ us-west-2a      │ us-west-2b      │ us-west-2c                          │    │
│  ├─────────────────┼─────────────────┼─────────────────────────────────────┤    │
│  │ Public Subnet   │ Public Subnet   │ Public Subnet                       │    │
│  │ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────┐                     │    │
│  │ │ NAT Gateway │ │ │ NAT Gateway │ │ │ NAT Gateway │                     │    │
│  │ │ + EIP       │ │ │ + EIP       │ │ │ + EIP       │                     │    │
│  │ └─────────────┘ │ └─────────────┘ │ └─────────────┘                     │    │
│  ├─────────────────┼─────────────────┼─────────────────────────────────────┤    │
│  │ Private Subnet  │ Private Subnet  │ Private Subnet                      │    │
│  │ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────┐                     │    │
│  │ │ EKS Nodes   │ │ │ EKS Nodes   │ │ │ EKS Nodes   │                     │    │
│  │ │ + Kasten K10│ │ │ + Kasten K10│ │ │ + Kasten K10│                     │    │
│  │ └─────────────┘ │ └─────────────┘ │ └─────────────┘                     │    │
│  └─────────────────┴─────────────────┴─────────────────────────────────────┘    │
│                                                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                        EKS Control Plane                               │    │
│  │  • Kubernetes 1.29 • OIDC Provider • Encryption at Rest              │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                       │                                         │
│                                       ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                         S3 Backup Storage                              │    │
│  │              • Encrypted backups • Cross-region replication           │    │
│  │              • Lifecycle policies • Cost optimization                  │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────┘
```

> **Author**: LT - [GitHub Profile](https://github.com/uldyssian-sh) · **Version**: 2.0 · **License**: MIT

---

## ✨ Features

- **🚀 Multiple Deployment Options** - Shell scripts and Terraform IaC
- **🔒 Production Security** - IAM roles, encryption, network isolation
- **📊 Enterprise Monitoring** - Prometheus, Grafana, CloudWatch integration
- **⚡ Automated Backup** - Scheduled policies with S3 long-term storage
- **🔄 Disaster Recovery** - Cross-region backup and restore capabilities
- **💰 Cost Optimization** - Spot instances, autoscaling, resource tagging
- **🛡️ Compliance Ready** - Security best practices and audit logging
- **📈 Scalable Architecture** - Auto-scaling node groups and storage

---

## 🚀 Quick Start

### Option 1: Shell Scripts (Fastest)
```bash
git clone https://github.com/uldyssian-sh/aws-eks-cluster-kasten.git
cd aws-eks-cluster-kasten
chmod +x scripts/*.sh

# Deploy EKS cluster
./scripts/create-simple-eks.sh

# Deploy Kasten K10
./scripts/deploy-kasten.sh

# Get dashboard URL
./scripts/get-kasten-url.sh
```

### Option 2: Terraform (Production)
```bash
cd terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="cluster_name=my-kasten-cluster"

# Deploy infrastructure
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name my-kasten-cluster
```

### Option 3: Helm Chart
```bash
# Add Kasten repository
helm repo add kasten https://charts.kasten.io/
helm repo update

# Deploy using custom chart
helm install k10 ./helm/kasten-k10 -n kasten-io --create-namespace
```

---

## 📋 Prerequisites

### Required Tools
| Tool | Version | Installation |
|------|---------|-------------|
| **AWS CLI** | v2.0+ | `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"` |
| **kubectl** | v1.28+ | `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"` |
| **eksctl** | v0.150+ | `curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"` |
| **Terraform** | v1.6+ | `wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip` |
| **Helm** | v3.12+ | `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \| bash` |

### AWS Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:*",
        "iam:*",
        "s3:*",
        "cloudformation:*"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 📁 Repository Structure

```
aws-eks-cluster-kasten/
├── scripts/                 # Shell scripts for quick deployment
│   ├── create-simple-eks.sh # EKS cluster creation
│   ├── deploy-kasten.sh     # Kasten K10 deployment
│   ├── get-kasten-url.sh    # Dashboard access
│   └── destroy-*.sh         # Cleanup scripts
├── terraform/               # Infrastructure as Code
│   ├── main.tf             # Main Terraform configuration
│   ├── variables.tf        # Input variables
│   └── outputs.tf          # Output values
├── helm/                   # Helm charts
│   └── kasten-k10/         # Custom Kasten deployment
├── examples/               # Usage examples and templates
│   ├── monitoring-stack.yaml
│   └── backup-policies/
├── docs/                   # Documentation
├── tests/                  # Automated tests
└── .github/workflows/      # CI/CD pipelines
```

---

## 🔧 Configuration Options

### Terraform Variables
```hcl
# terraform.tfvars
cluster_name = "production-kasten"
aws_region = "us-west-2"
environment = "prod"

# Node configuration
node_instance_types = ["t3.large"]
node_group_desired_size = 5
node_disk_size = 100

# Security
allowed_cidr_blocks = ["10.0.0.0/8"]
enable_encryption = true

# Monitoring
enable_monitoring = true
enable_logging = true
```

### Environment Variables
```bash
export AWS_REGION=us-west-2
export CLUSTER_NAME=kasten-eks
export KASTEN_NAMESPACE=kasten-io
export S3_BUCKET_NAME=my-kasten-backups
```

---

## 📊 Monitoring and Observability

### Prometheus Metrics
```yaml
# Deploy monitoring stack
kubectl apply -f examples/monitoring-stack.yaml

# Access Grafana dashboard
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

### Key Metrics
- Backup success/failure rates
- Recovery time objectives (RTO)
- Storage utilization
- Policy compliance
- Cost optimization metrics

### CloudWatch Integration
```bash
# Enable container insights
aws eks update-cluster-config \
  --region us-west-2 \
  --name kasten-eks \
  --logging '{"enable":["api","audit","authenticator","controllerManager","scheduler"]}'
```

---

## 💰 Cost Optimization

### Resource Sizing
| Component | Instance Type | Monthly Cost (us-west-2) |
|-----------|---------------|-------------------------|
| EKS Control Plane | Managed | $73.00 |
| Worker Nodes (3x) | t3.medium | ~$95.00 |
| EBS Volumes | gp3 (50GB each) | ~$15.00 |
| Load Balancer | ALB | ~$22.00 |
| S3 Storage | Standard | ~$5.00/TB |
| **Total Estimated** | | **~$210.00/month** |

### Cost Reduction Strategies
```hcl
# Use Spot instances
node_capacity_type = "SPOT"

# Enable autoscaling
node_group_min_size = 1
node_group_max_size = 10

# Use S3 Intelligent Tiering
lifecycle_configuration {
  rule {
    id     = "intelligent_tiering"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}
```

---

## 🔐 Security Best Practices

### Network Security
- **Private subnets** for worker nodes
- **Security groups** with minimal required access
- **VPC endpoints** for AWS services
- **Network policies** for pod-to-pod communication

### IAM Security
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::kasten-backups/*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-west-2"
        }
      }
    }
  ]
}
```

### Encryption
- **EBS volumes** encrypted with AWS KMS
- **S3 buckets** with server-side encryption
- **Secrets** stored in AWS Secrets Manager
- **TLS** for all communications

---

## 🧪 Testing and Validation

### Automated Tests
```bash
# Run validation tests
./tests/validate-deployment.sh

# Test backup and restore
./tests/test-backup-restore.sh

# Performance testing
./tests/load-test.sh
```

### Manual Validation
```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A

# Verify Kasten installation
kubectl get pods -n kasten-io
kubectl get svc -n kasten-io

# Test backup functionality
kubectl apply -f examples/test-application.yaml
```

---

## 🔄 Backup and Recovery Workflows

### Automated Backup Policies
```yaml
apiVersion: config.kio.kasten.io/v1alpha1
kind: Policy
metadata:
  name: daily-backup-policy
  namespace: kasten-io
spec:
  frequency: "@daily"
  retention:
    daily: 7
    weekly: 4
    monthly: 12
  actions:
    - action: backup
      backupParameters:
        profile:
          name: s3-backup-location
```

### Disaster Recovery Testing
```bash
# Create test workload
kubectl create namespace test-dr
kubectl create deployment nginx --image=nginx -n test-dr

# Backup namespace
# Delete namespace
kubectl delete namespace test-dr

# Restore from backup using Kasten dashboard
```

---

## 📚 Documentation

- [Installation Guide](docs/INSTALLATION.md) - Detailed setup instructions
- [Configuration Guide](docs/CONFIGURATION.md) - Advanced configuration options
- [Security Guide](docs/SECURITY.md) - Security best practices
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [API Reference](docs/API.md) - Terraform and Helm API documentation

---

## 🤝 Contributing

### Development Setup
```bash
# Fork and clone repository
git clone https://github.com/your-username/aws-eks-cluster-kasten.git
cd aws-eks-cluster-kasten

# Install development tools
make install-dev-tools

# Run tests
make test

# Submit pull request
```

### Testing Checklist
- [ ] Scripts execute without errors
- [ ] Terraform plan/apply succeeds
- [ ] All AWS resources created correctly
- [ ] Kasten dashboard accessible
- [ ] Backup/restore functionality works
- [ ] Cleanup scripts remove all resources
- [ ] No sensitive data in code

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Kasten** for the excellent K10 data protection platform
- **AWS** for managed Kubernetes and cloud services
- **Terraform** community for infrastructure modules
- **Kubernetes** community for container orchestration

---

## 📞 Support

### Community Resources
- [Kasten Community Slack](https://kasten.io/slack)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Issues and Feature Requests
Create an issue in this repository with:
- Detailed description
- Steps to reproduce
- Expected vs actual behavior
- Environment details (AWS region, versions, etc.)

---

**⚠️ Production Notes:**
- Always test in non-production environments first
- Monitor AWS costs during deployment
- Implement proper backup testing and validation
- Follow security best practices for production use
- Keep tools and dependencies updated

**🎯 Success Metrics:**
- Cluster deployment: < 20 minutes
- Kasten installation: < 15 minutes
- Backup completion: < 30 minutes
- Recovery time: < 10 minutes
## 🔒 Security Notice

This repository contains example configurations and templates. Before using in production:

1. **Replace all placeholder values** with your actual credentials
2. **Use environment variables** for sensitive data (see `.env.example`)
3. **Never commit real passwords** or API keys to version control
4. **Follow the principle of least privilege** for all access controls
5. **Regularly rotate credentials** and access keys

For more security guidelines, see [SECURITY.md](SECURITY.md).

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on:
- How to submit issues
- How to propose changes
- Code style guidelines
- Review process

## 🤖 AI Development Support

This repository is optimized for AI-assisted development:
- **Amazon Q Developer**: Enhanced AWS and cloud development assistance
- **GitHub Copilot**: Code completion and suggestions
- **AI-friendly documentation**: Clear structure for better AI understanding

See [AMAZON_Q_INTEGRATION.md](AMAZON_Q_INTEGRATION.md) for detailed setup and usage.

## Support

- 📖 [Wiki Documentation](../../wiki)
- 💬 [Discussions](../../discussions)
- 🐛 [Issue Tracker](../../issues)
- 🔒 [Security Policy](SECURITY.md)

---
**Made with ❤️ for the community**
