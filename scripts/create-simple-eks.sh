#!/usr/bin/env bash
set -euo pipefail

CYAN="\033[0;36m"; MAGENTA="\033[0;35m"; GREEN="\033[0;32m"; RED="\033[0;31m"; NC="\033[0m"

echo -e "${MAGENTA}=== Simple EKS Cluster Creation ===${NC}"

echo -e "${CYAN}Cluster name [kasten-eks]: ${NC}"
read -r CLUSTER_NAME
CLUSTER_NAME="${CLUSTER_NAME:-kasten-eks}"

echo -e "${CYAN}AWS Region [us-west-2]: ${NC}"
read -r AWS_REGION
AWS_REGION="${AWS_REGION:-us-west-2}"

echo -e "${MAGENTA}Using eksctl to create cluster (much simpler)...${NC}"

# Check if eksctl is installed
if ! command -v eksctl &> /dev/null; then
    echo -e "${RED}eksctl not found. Installing...${NC}"
    # Install eksctl on macOS
    if command -v brew &> /dev/null; then
        brew tap weaveworks/tap
        brew install weaveworks/tap/eksctl
    else
        echo -e "${RED}Please install eksctl manually: https://eksctl.io/installation/${NC}"
        exit 1
    fi
fi

echo -e "${MAGENTA}Creating EKS cluster with eksctl...${NC}"
eksctl create cluster \
  --name="${CLUSTER_NAME}" \
  --region="${AWS_REGION}" \
  --version=1.29 \
  --nodegroup-name=workers \
  --node-type=t3.medium \
  --nodes=3 \
  --nodes-min=1 \
  --nodes-max=5 \
  --managed \
  --with-oidc \
  --ssh-access=false

echo -e "${MAGENTA}Installing AWS Load Balancer Controller...${NC}"
# Create proper ALB controller policy
cat > /tmp/alb-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "elasticloadbalancing:*",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "cognito-idp:DescribeUserPoolClient",
                "waf-regional:*",
                "wafv2:*",
                "shield:*",
                "acm:ListCertificates",
                "acm:DescribeCertificate"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags"
            ],
            "Resource": "*"
        }
    ]
}
EOF

ALB_POLICY_ARN=$(aws iam create-policy \
  --policy-name "AWSLoadBalancerControllerIAMPolicy-${CLUSTER_NAME}" \
  --policy-document file:///tmp/alb-policy.json \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || \
  aws iam list-policies --scope Local --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy-${CLUSTER_NAME}'].Arn" --output text)

# Cleanup temporary file
rm -f /tmp/alb-policy.json

eksctl create iamserviceaccount \
  --cluster="${CLUSTER_NAME}" \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name "AmazonEKSLoadBalancerControllerRole-${CLUSTER_NAME}" \
  --attach-policy-arn="${ALB_POLICY_ARN}" \
  --region="${AWS_REGION}" \
  --override-existing-serviceaccounts \
  --approve

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${AWS_REGION}"

echo -e "${MAGENTA}Waiting for controller to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s

echo -e "${MAGENTA}Installing EBS CSI Driver...${NC}"
eksctl create addon --name aws-ebs-csi-driver --cluster="${CLUSTER_NAME}" --region="${AWS_REGION}" --force

echo -e "${MAGENTA}Waiting for EBS CSI Driver to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=ebs-csi-controller -n kube-system --timeout=300s || echo "EBS CSI Driver may still be starting"

echo -e "${MAGENTA}Creating immediate binding storage class...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2-immediate
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
volumeBindingMode: Immediate
allowVolumeExpansion: true
reclaimPolicy: Delete
EOF

# Get cluster info
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --query "cluster.resourcesVpcConfig.vpcId" --output text)

cat > .env <<ENV
CLUSTER_NAME=${CLUSTER_NAME}
AWS_REGION=${AWS_REGION}
VPC_ID=${VPC_ID}
ENV

echo -e "${GREEN}=== EKS Cluster Ready ===${NC}"
echo -e "${CYAN}Cluster: ${CLUSTER_NAME}${NC}"
echo -e "${CYAN}Region: ${AWS_REGION}${NC}"
echo -e "${CYAN}VPC: ${VPC_ID}${NC}"
echo -e "${CYAN}Ready for Kasten K10!${NC}"