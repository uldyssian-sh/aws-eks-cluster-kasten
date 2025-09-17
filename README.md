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

```bash
# Deploy EKS cluster
terraform init
terraform apply

# Install Kasten K10
helm repo add kasten https://charts.kasten.io/
helm install k10 kasten/k10 --namespace kasten-io --create-namespace

# Access K10 Dashboard
kubectl port-forward service/gateway 8080:8000 --namespace kasten-io
# Open http://localhost:8080/k10/
```

## 📚 Documentation

- [Installation Guide](https://github.com/uldyssian-sh/aws-eks-cluster-kasten/wiki/Installation)
- [Backup Configuration](https://github.com/uldyssian-sh/aws-eks-cluster-kasten/wiki/Backup-Config)
- [Disaster Recovery](https://github.com/uldyssian-sh/aws-eks-cluster-kasten/wiki/Disaster-Recovery)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.
