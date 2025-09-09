# AWS EKS Cluster with Kasten K10 Backup Solution

A comprehensive automation suite for deploying Amazon EKS clusters with Kasten K10 data protection platform. This repository provides production-ready scripts for creating, configuring, and managing Kubernetes backup and disaster recovery solutions on AWS.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Cloud Environment                    │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐  │
│  │   Amazon EKS    │    │  AWS IAM Roles  │    │   Amazon    │  │
│  │    Cluster      │◄──►│   & Policies    │◄──►│     S3      │  │
│  │                 │    │                 │    │   Bucket    │  │
│  │ ┌─────────────┐ │    │ • Kasten Role   │    │             │  │
│  │ │ Kasten K10  │ │    │ • EBS CSI Role  │    │ (Backups)   │  │
│  │ │ Dashboard   │ │    │ • ALB Role      │    │             │  │
│  │ └─────────────┘ │    │ • Node Role     │    │             │  │
│  │                 │    └─────────────────┘    └─────────────┘  │
│  │ ┌─────────────┐ │                                            │
│  │ │Worker Nodes │ │    ┌─────────────────┐    ┌─────────────┐  │
│  │ │ (t3.medium) │ │    │ Application     │    │   AWS EBS   │  │
│  │ │   x3 nodes  │ │◄──►│ Load Balancer   │◄──►│   Volumes   │  │
│  │ └─────────────┘ │    │   Controller    │    │             │  │
│  └─────────────────┘    └─────────────────┘    └─────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

- **Amazon EKS Cluster**: Managed Kubernetes service with 3 worker nodes
- **Kasten K10**: Enterprise-grade backup and disaster recovery platform
- **AWS Load Balancer Controller**: Manages ALB/NLB for ingress traffic
- **EBS CSI Driver**: Enables persistent volume provisioning
- **IAM Roles & Policies**: Secure access control for all components
- **S3 Integration**: Long-term backup storage destination

## 📋 Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|-------------|
| **AWS CLI** | v2.0+ | `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"` |
| **kubectl** | v1.28+ | `curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"` |
| **eksctl** | v0.150+ | `curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"` |
| **Helm** | v3.12+ | `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \| bash` |

### AWS Requirements

#### IAM Permissions
Your AWS user/role must have the following permissions:
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`
- `IAMFullAccess` (for creating service roles)
- `EC2FullAccess` (for VPC and security groups)
- `S3FullAccess` (for backup storage)

#### AWS Configuration
```bash
# Configure AWS credentials
aws configure
# Follow prompts to enter your AWS credentials
# Default region name: us-west-2
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

### System Requirements
- **Operating System**: Linux, macOS, or WSL2
- **Memory**: 4GB+ RAM
- **Storage**: 10GB+ free space
- **Network**: Internet connectivity for downloading container images

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/uldyssian-sh/aws-eks-cluster-kasten.git
cd aws-eks-cluster-kasten
chmod +x scripts/*.sh
```

### 2. Deploy EKS Cluster
```bash
./scripts/create-simple-eks.sh
```
**Input prompts:**
- Cluster name (default: kasten-eks)
- AWS Region (default: us-west-2)

### 3. Deploy Kasten K10
```bash
./scripts/deploy-kasten.sh
```
**Input prompts:**
- EKS Cluster name
- AWS Region
- Kasten namespace (default: kasten-io)
- Domain name for HTTPS access
- S3 bucket name for backups
- SSL certificate details

### 4. Access Dashboard
```bash
./scripts/get-kasten-url.sh
```

## 📁 Script Documentation

### 🔧 create-simple-eks.sh

**Purpose**: Creates a production-ready EKS cluster with essential add-ons.

**What it does:**
1. **Cluster Creation**: Uses eksctl to create EKS cluster with managed node groups
2. **ALB Controller**: Installs AWS Load Balancer Controller for ingress management
3. **EBS CSI Driver**: Enables persistent volume provisioning
4. **Storage Class**: Creates immediate-binding storage class for Kasten
5. **Networking**: Configures VPC, subnets, and security groups

**Resources Created:**
- EKS Cluster (v1.29)
- 3x t3.medium worker nodes (auto-scaling 1-5)
- VPC with public/private subnets
- IAM roles and policies
- EBS CSI driver addon
- ALB controller

**Execution Time**: ~15-20 minutes

### 🛡️ deploy-kasten.sh

**Purpose**: Deploys Kasten K10 data protection platform on EKS.

**What it does:**
1. **SSL Certificate**: Generates self-signed certificate for HTTPS
2. **IAM Setup**: Creates Kasten-specific IAM role with S3 permissions
3. **Helm Installation**: Deploys Kasten K10 using official Helm chart
4. **Service Configuration**: Sets up LoadBalancer for external access
5. **Authentication**: Configures token-based authentication
6. **Storage Integration**: Prepares S3 backup location profile

**Resources Created:**
- Kasten K10 namespace and pods
- TLS secret for HTTPS
- IAM role with S3 permissions
- LoadBalancer service
- Cluster role binding for authentication

**Execution Time**: ~10-15 minutes

### 🔍 get-kasten-url.sh

**Purpose**: Retrieves Kasten dashboard URL and authentication token.

**What it does:**
1. **Service Check**: Verifies Kasten deployment status
2. **LoadBalancer**: Creates/patches gateway service for external access
3. **URL Retrieval**: Gets external LoadBalancer hostname
4. **Token Generation**: Creates 24-hour authentication token
5. **Access Info**: Saves access details to artifacts file

**Output:**
- Dashboard URL
- Authentication token
- Access instructions

### 🧪 test-permissions.sh

**Purpose**: Validates AWS permissions and cluster connectivity.

**What it does:**
1. **AWS Permissions**: Tests IAM permissions for EKS operations
2. **Cluster Access**: Verifies kubectl connectivity
3. **Service Status**: Checks Kasten pod health
4. **Storage**: Validates PVC binding
5. **Network**: Tests LoadBalancer connectivity

### 🗑️ destroy-kasten.sh

**Purpose**: Removes Kasten K10 and associated resources.

**What it does:**
1. **Helm Cleanup**: Uninstalls Kasten K10 Helm release
2. **Namespace Deletion**: Removes kasten-io namespace
3. **IAM Cleanup**: Deletes Kasten-specific roles and policies
4. **Storage Cleanup**: Removes storage class and PVCs
5. **Verification**: Confirms all resources are deleted

**Verification Report:**
- ✅ Kasten IAM Roles: 0 remaining
- ✅ Kasten IAM Policies: 0 remaining
- ✅ Namespace: Deleted
- ✅ Helm Release: Removed

### 🗑️ destroy-simple-eks.sh

**Purpose**: Completely removes EKS cluster and all AWS resources.

**What it does:**
1. **ALB Controller**: Uninstalls AWS Load Balancer Controller
2. **EBS CSI**: Removes EBS CSI driver addon
3. **Cluster Deletion**: Uses eksctl to delete entire cluster
4. **IAM Cleanup**: Removes ALB controller policies
5. **Verification**: Confirms complete cleanup

**Verification Report:**
- ✅ EKS Clusters: 0 remaining
- ✅ CloudFormation Stacks: 0 remaining
- ✅ ALB IAM Policies: 0 remaining
- 🎯 All AWS resources cleared successfully!

## 🔐 Security Features

### IAM Best Practices
- **Least Privilege**: Each component has minimal required permissions
- **Service Accounts**: Uses Kubernetes service accounts with IAM roles
- **OIDC Integration**: Secure token exchange between EKS and AWS
- **Policy Scoping**: S3 permissions limited to specific bucket

### Network Security
- **Private Subnets**: Worker nodes in private subnets
- **Security Groups**: Restrictive ingress/egress rules
- **TLS Encryption**: HTTPS for dashboard access
- **Load Balancer**: AWS ALB with security groups

### Data Protection
- **Encryption**: EBS volumes encrypted at rest
- **S3 Security**: Server-side encryption for backups
- **Access Control**: Token-based authentication
- **Audit Logging**: CloudTrail integration

## 📊 Cost Optimization

### Resource Sizing
| Component | Instance Type | Monthly Cost (us-west-2) |
|-----------|---------------|-------------------------|
| EKS Control Plane | Managed | $73.00 |
| Worker Nodes (3x) | t3.medium | ~$95.00 |
| EBS Volumes | gp3 (20GB each) | ~$6.00 |
| Load Balancer | ALB | ~$22.00 |
| **Total Estimated** | | **~$196.00/month** |

### Cost Reduction Tips
- Use Spot instances for non-production workloads
- Enable cluster autoscaler for dynamic scaling
- Schedule non-critical workloads during off-hours
- Use S3 Intelligent Tiering for backup storage

## 🔧 Troubleshooting

### Common Issues

#### 1. EKS Cluster Creation Fails
```bash
# Check AWS permissions
aws sts get-caller-identity
aws iam get-user

# Verify eksctl version
eksctl version

# Check region availability
aws ec2 describe-availability-zones --region us-west-2
```

#### 2. Kasten Pods Stuck in Pending
```bash
# Check PVC status
kubectl get pvc -n kasten-io

# Verify storage class
kubectl get storageclass

# Check EBS CSI driver
kubectl get pods -n kube-system | grep ebs-csi
```

#### 3. LoadBalancer Not Getting External IP
```bash
# Check ALB controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Verify service
kubectl describe svc gateway -n kasten-io

# Check AWS Load Balancers
aws elbv2 describe-load-balancers --region us-west-2
```

#### 4. Authentication Token Issues
```bash
# Generate new token
kubectl create token gateway -n kasten-io --duration=24h

# Check service account
kubectl get serviceaccount gateway -n kasten-io

# Verify cluster role binding
kubectl get clusterrolebinding k10-admin
```

### Debug Commands
```bash
# Check all Kasten pods
kubectl get pods -n kasten-io -o wide

# View pod logs
kubectl logs -n kasten-io deployment/catalog-svc

# Describe problematic pod
kubectl describe pod -n kasten-io <pod-name>

# Check events
kubectl get events -n kasten-io --sort-by='.lastTimestamp'
```

## 🔄 Backup and Recovery Workflows

### Setting Up S3 Backup Location
1. Access Kasten dashboard
2. Navigate to Settings → Location Profiles
3. Create new S3 profile:
   - **Name**: s3-backup-location
   - **Type**: S3
   - **Bucket**: Your S3 bucket name
   - **Region**: us-west-2
   - **Credentials**: Use IAM role (automatic)

### Creating Backup Policies
1. Go to Policies → Create New Policy
2. Configure policy:
   - **Applications**: Select namespaces to backup
   - **Schedule**: Define backup frequency
   - **Retention**: Set retention period
   - **Location**: Select S3 profile

### Disaster Recovery Testing
```bash
# Create test application
kubectl create namespace test-app
kubectl create deployment nginx --image=nginx -n test-app

# Create backup policy for test-app namespace
# Trigger manual backup
# Delete namespace
kubectl delete namespace test-app

# Restore from backup using Kasten dashboard
```

## 📈 Monitoring and Observability

### Kasten Metrics
- Backup success/failure rates
- Recovery time objectives (RTO)
- Recovery point objectives (RPO)
- Storage utilization
- Policy compliance

### AWS CloudWatch Integration
```bash
# Enable container insights
aws eks update-cluster-config \
  --region us-west-2 \
  --name kasten-eks \
  --logging '{"enable":["api","audit","authenticator","controllerManager","scheduler"]}'
```

### Prometheus Integration
Kasten K10 exposes Prometheus metrics at `/k10/prometheus/federate`

## 🔄 Upgrade Procedures

### Upgrading Kasten K10
```bash
# Update Helm repository
helm repo update kasten

# Check available versions
helm search repo kasten/k10 --versions

# Upgrade to latest version
helm upgrade k10 kasten/k10 -n kasten-io --reuse-values
```

### Upgrading EKS Cluster
```bash
# Check current version
kubectl version --short

# Upgrade cluster
eksctl upgrade cluster --name kasten-eks --region us-west-2

# Upgrade node groups
eksctl upgrade nodegroup --cluster kasten-eks --name workers --region us-west-2
```

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Test changes thoroughly
4. Submit pull request

### Testing Checklist
- [ ] Scripts execute without errors
- [ ] All AWS resources are created correctly
- [ ] Kasten dashboard is accessible
- [ ] Backup/restore functionality works
- [ ] Cleanup scripts remove all resources
- [ ] No sensitive data in scripts

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**LT** - [GitHub Profile](https://github.com/uldyssian-sh)

## 🔗 Repository

[aws-eks-cluster-kasten](https://github.com/uldyssian-sh/aws-eks-cluster-kasten)

## 🆘 Support

### Documentation
- [Kasten K10 Documentation](https://docs.kasten.io/)
- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

### Community
- [Kasten Community Slack](https://kasten.io/slack)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### Issues
For bugs and feature requests, please create an issue in this repository with:
- Detailed description
- Steps to reproduce
- Expected vs actual behavior
- Environment details (AWS region, versions, etc.)

---

**⚠️ Important Notes:**
- Always test in non-production environments first
- Monitor AWS costs during deployment
- Ensure proper backup testing and validation
- Follow security best practices for production use
- Keep scripts and tools updated to latest versions

**🎯 Success Metrics:**
- Cluster deployment: < 20 minutes
- Kasten installation: < 15 minutes
- Backup completion: < 30 minutes (varies by data size)
- Recovery time: < 10 minutes (varies by data size)