# AWS EKS Cluster with Kasten K10

<div align="center">

```
┌─────────────────────────────────────────────────────────────┐
│                EKS + Kasten K10 Architecture                │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ EKS Cluster │────│ Kasten K10  │────│ S3 Backup   │     │
│  │Applications │    │Data Services│    │  Storage    │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│         │                   │                   │          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │ Persistent  │    │ Backup      │    │ Disaster    │     │
│  │  Volumes    │    │ Policies    │    │ Recovery    │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
```
  
  [![EKS](https://img.shields.io/badge/AWS-EKS-FF9900.svg)](https://aws.amazon.com/eks/)
  [![Kasten K10](https://img.shields.io/badge/Kasten-K10-blue.svg)](https://www.kasten.io/)
  [![Backup](https://img.shields.io/badge/Backup-Disaster%20Recovery-green.svg)](https://www.kasten.io/product/)
</div>

## 🔄 Overview

Production-ready EKS cluster with Kasten K10 for Kubernetes backup, disaster recovery, and application mobility. Complete data protection solution for cloud-native applications.

## 🎯 Features

- **Automated Backups**: Application-consistent backups
- **Disaster Recovery**: Cross-region and cross-cloud recovery
- **Application Mobility**: Migrate applications between clusters
- **Policy Management**: Automated backup policies
- **Compliance**: Regulatory compliance reporting

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed
- Helm 3.x installed
- Terraform >= 1.5 (optional)
- Docker (optional)

### Quick Deployment

```bash
# Create EKS cluster
./scripts/create-eks-cluster.sh

# Deploy Kasten K10
./scripts/deploy-kasten.sh

# Get access URL
./scripts/get-kasten-url.sh
```

### Terraform Deployment

```bash
# Initialize Terraform
cd terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply
```

## 📖 Documentation

- [Installation Guide](docs/README.md)
- [Configuration Guide](terraform/variables.tf)
- [Examples](examples/)
- [Scripts Documentation](scripts/)
- [Helm Charts](helm/)

## 🔧 Configuration

Configuration can be done through:

1. **Terraform Variables** - See [variables.tf](terraform/variables.tf)
2. **Environment Variables** - AWS credentials and region
3. **Script Parameters** - Interactive configuration

## 📊 Usage Examples

### Basic EKS Cluster

```bash
# Create simple EKS cluster
./scripts/create-simple-eks.sh
```

### Advanced Configuration

```bash
# Use Terraform for production deployment
cd terraform
terraform apply -var="environment=prod" -var="node_instance_types=[\"m5.large\"]"
```

## 🧪 Testing

Validate your deployment:

```bash
# Test AWS permissions
./scripts/test-permissions.sh

# Validate Terraform configuration
cd terraform && terraform validate

# Check cluster status
kubectl get nodes
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md).

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.
# Updated 20251109_123800
# Updated Sun Nov  9 12:50:08 CET 2025
