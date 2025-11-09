#!/usr/bin/env bash
set -euo pipefail

CYAN="\033[0;36m"; MAGENTA="\033[0;35m"; GREEN="\033[0;32m"; RED="\033[0;31m"; NC="\033[0m"

echo -e "${MAGENTA}=== EKS Cluster Creation for Kasten K10 ===${NC}"

# Interactive inputs
echo -e "${CYAN}EKS Cluster name [kasten-cluster]: ${NC}"
read -r CLUSTER_NAME
CLUSTER_NAME="${CLUSTER_NAME:-kasten-cluster}"

echo -e "${CYAN}AWS Region [us-west-2]: ${NC}"
read -r AWS_REGION
AWS_REGION="${AWS_REGION:-us-west-2}"

echo -e "${CYAN}Kubernetes version [1.29]: ${NC}"
read -r K8S_VERSION
K8S_VERSION="${K8S_VERSION:-1.29}"

echo -e "${CYAN}Node instance type [t3.medium]: ${NC}"
read -r INSTANCE_TYPE
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.medium}"

echo -e "${CYAN}Desired node count [3]: ${NC}"
read -r NODE_COUNT
NODE_COUNT="${NODE_COUNT:-3}"

echo -e "${CYAN}VPC CIDR [10.0.0.0/16]: ${NC}"
read -r VPC_CIDR
VPC_CIDR="${VPC_CIDR:-10.0.0.0/16}"

echo -e "${MAGENTA}Creating VPC for EKS cluster...${NC}"
VPC_ID=$(aws ec2 create-vpc --cidr-block "${VPC_CIDR}" --query 'Vpc.VpcId' --output text --region "${AWS_REGION}")
aws ec2 create-tags --resources "${VPC_ID}" --tags Key=Name,Value="${CLUSTER_NAME}-vpc" --region "${AWS_REGION}"
aws ec2 modify-vpc-attribute --vpc-id "${VPC_ID}" --enable-dns-hostnames --region "${AWS_REGION}"
aws ec2 modify-vpc-attribute --vpc-id "${VPC_ID}" --enable-dns-support --region "${AWS_REGION}"

echo -e "${MAGENTA}Creating Internet Gateway...${NC}"
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text --region "${AWS_REGION}")
aws ec2 create-tags --resources "${IGW_ID}" --tags Key=Name,Value="${CLUSTER_NAME}-igw" --region "${AWS_REGION}"
aws ec2 attach-internet-gateway --internet-gateway-id "${IGW_ID}" --vpc-id "${VPC_ID}" --region "${AWS_REGION}"

echo -e "${MAGENTA}Creating subnets...${NC}"
mapfile -t AZS < <(aws ec2 describe-availability-zones --region "${AWS_REGION}" --query 'AvailabilityZones[0:3].ZoneName' --output text | tr '\t' '\n')

# Public subnets
PUB_SUBNET_1=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "10.0.1.0/24" --availability-zone "${AZS[0]}" --query 'Subnet.SubnetId' --output text --region "${AWS_REGION}")
PUB_SUBNET_2=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "10.0.2.0/24" --availability-zone "${AZS[1]}" --query 'Subnet.SubnetId' --output text --region "${AWS_REGION}")
PUB_SUBNET_3=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "10.0.3.0/24" --availability-zone "${AZS[2]}" --query 'Subnet.SubnetId' --output text --region "${AWS_REGION}")

# Private subnets
PRV_SUBNET_1=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "10.0.101.0/24" --availability-zone "${AZS[0]}" --query 'Subnet.SubnetId' --output text --region "${AWS_REGION}")
PRV_SUBNET_2=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "10.0.102.0/24" --availability-zone "${AZS[1]}" --query 'Subnet.SubnetId' --output text --region "${AWS_REGION}")
PRV_SUBNET_3=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "10.0.103.0/24" --availability-zone "${AZS[2]}" --query 'Subnet.SubnetId' --output text --region "${AWS_REGION}")

# Tag subnets
aws ec2 create-tags --resources "${PUB_SUBNET_1}" "${PUB_SUBNET_2}" "${PUB_SUBNET_3}" --tags Key=Name,Value="${CLUSTER_NAME}-public" Key=kubernetes.io/role/elb,Value=1 --region "${AWS_REGION}"
aws ec2 create-tags --resources "${PRV_SUBNET_1}" "${PRV_SUBNET_2}" "${PRV_SUBNET_3}" --tags Key=Name,Value="${CLUSTER_NAME}-private" Key=kubernetes.io/role/internal-elb,Value=1 --region "${AWS_REGION}"

# Enable auto-assign public IP for public subnets
aws ec2 modify-subnet-attribute --subnet-id "${PUB_SUBNET_1}" --map-public-ip-on-launch --region "${AWS_REGION}"
aws ec2 modify-subnet-attribute --subnet-id "${PUB_SUBNET_2}" --map-public-ip-on-launch --region "${AWS_REGION}"
aws ec2 modify-subnet-attribute --subnet-id "${PUB_SUBNET_3}" --map-public-ip-on-launch --region "${AWS_REGION}"

echo -e "${MAGENTA}Creating NAT Gateway...${NC}"
EIP_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text --region "${AWS_REGION}")
NAT_GW_ID=$(aws ec2 create-nat-gateway --subnet-id "${PUB_SUBNET_1}" --allocation-id "${EIP_ID}" --query 'NatGateway.NatGatewayId' --output text --region "${AWS_REGION}")
aws ec2 create-tags --resources "${NAT_GW_ID}" --tags Key=Name,Value="${CLUSTER_NAME}-nat" --region "${AWS_REGION}"

echo -e "${MAGENTA}Creating route tables...${NC}"
# Public route table
PUB_RT_ID=$(aws ec2 create-route-table --vpc-id "${VPC_ID}" --query 'RouteTable.RouteTableId' --output text --region "${AWS_REGION}")
aws ec2 create-tags --resources "${PUB_RT_ID}" --tags Key=Name,Value="${CLUSTER_NAME}-public-rt" --region "${AWS_REGION}"
aws ec2 create-route --route-table-id "${PUB_RT_ID}" --destination-cidr-block "0.0.0.0/0" --gateway-id "${IGW_ID}" --region "${AWS_REGION}"

# Associate public subnets
aws ec2 associate-route-table --subnet-id "${PUB_SUBNET_1}" --route-table-id "${PUB_RT_ID}" --region "${AWS_REGION}"
aws ec2 associate-route-table --subnet-id "${PUB_SUBNET_2}" --route-table-id "${PUB_RT_ID}" --region "${AWS_REGION}"
aws ec2 associate-route-table --subnet-id "${PUB_SUBNET_3}" --route-table-id "${PUB_RT_ID}" --region "${AWS_REGION}"

# Wait for NAT Gateway to be available
echo -e "${MAGENTA}Waiting for NAT Gateway to be available...${NC}"
aws ec2 wait nat-gateway-available --nat-gateway-ids "${NAT_GW_ID}" --region "${AWS_REGION}"

# Private route table
PRV_RT_ID=$(aws ec2 create-route-table --vpc-id "${VPC_ID}" --query 'RouteTable.RouteTableId' --output text --region "${AWS_REGION}")
aws ec2 create-tags --resources "${PRV_RT_ID}" --tags Key=Name,Value="${CLUSTER_NAME}-private-rt" --region "${AWS_REGION}"
aws ec2 create-route --route-table-id "${PRV_RT_ID}" --destination-cidr-block "0.0.0.0/0" --nat-gateway-id "${NAT_GW_ID}" --region "${AWS_REGION}"

# Associate private subnets
aws ec2 associate-route-table --subnet-id "${PRV_SUBNET_1}" --route-table-id "${PRV_RT_ID}" --region "${AWS_REGION}"
aws ec2 associate-route-table --subnet-id "${PRV_SUBNET_2}" --route-table-id "${PRV_RT_ID}" --region "${AWS_REGION}"
aws ec2 associate-route-table --subnet-id "${PRV_SUBNET_3}" --route-table-id "${PRV_RT_ID}" --region "${AWS_REGION}"

echo -e "${MAGENTA}Creating EKS cluster IAM role...${NC}"
CLUSTER_ROLE_NAME="eksClusterRole-${CLUSTER_NAME}"
aws iam create-role --role-name "${CLUSTER_ROLE_NAME}" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "eks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }' >/dev/null || true

aws iam attach-role-policy --role-name "${CLUSTER_ROLE_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy || true
CLUSTER_ROLE_ARN=$(aws iam get-role --role-name "${CLUSTER_ROLE_NAME}" --query 'Role.Arn' --output text)

echo -e "${MAGENTA}Creating EKS cluster ${CLUSTER_NAME}...${NC}"
CREATE_OUTPUT=$(aws eks create-cluster \
  --name "${CLUSTER_NAME}" \
  --version "${K8S_VERSION}" \
  --role-arn "${CLUSTER_ROLE_ARN}" \
  --resources-vpc-config subnetIds="${PRV_SUBNET_1},${PRV_SUBNET_2},${PRV_SUBNET_3},${PUB_SUBNET_1},${PUB_SUBNET_2},${PUB_SUBNET_3}" \
  --region "${AWS_REGION}" 2>&1)

CREATE_EXIT_CODE=$?
echo "${CREATE_OUTPUT}"

if [ "${CREATE_EXIT_CODE}" -ne 0 ]; then
  echo -e "${RED}Failed to create EKS cluster. Error above shows the reason.${NC}"
  exit 1
fi

echo -e "${MAGENTA}Verifying cluster was created...${NC}"
if ! aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo -e "${RED}Cluster was not created successfully. Check AWS console for details.${NC}"
  echo -e "${RED}Common issues: IAM permissions, service limits, or region availability.${NC}"
  exit 1
fi

echo -e "${MAGENTA}Waiting for cluster to be active...${NC}"
aws eks wait cluster-active --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

echo -e "${MAGENTA}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

echo -e "${MAGENTA}Creating node group IAM role...${NC}"
NODE_ROLE_NAME="eksNodeRole-${CLUSTER_NAME}"
aws iam create-role --role-name "${NODE_ROLE_NAME}" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }' >/dev/null || true

aws iam attach-role-policy --role-name "${NODE_ROLE_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy || true
aws iam attach-role-policy --role-name "${NODE_ROLE_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy || true
aws iam attach-role-policy --role-name "${NODE_ROLE_NAME}" --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly || true
NODE_ROLE_ARN=$(aws iam get-role --role-name "${NODE_ROLE_NAME}" --query 'Role.Arn' --output text)

echo -e "${MAGENTA}Creating node group...${NC}"
aws eks create-nodegroup \
  --cluster-name "${CLUSTER_NAME}" \
  --nodegroup-name "${CLUSTER_NAME}-nodes" \
  --subnets "${PRV_SUBNET_1}" "${PRV_SUBNET_2}" "${PRV_SUBNET_3}" \
  --node-role "${NODE_ROLE_ARN}" \
  --instance-types "${INSTANCE_TYPE}" \
  --scaling-config minSize=1,maxSize=5,desiredSize="${NODE_COUNT}" \
  --region "${AWS_REGION}"

if ! aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo -e "${RED}Failed to create node group. Exiting.${NC}"
  exit 1
fi

echo -e "${MAGENTA}Waiting for node group to be active...${NC}"
aws eks wait nodegroup-active --cluster-name "${CLUSTER_NAME}" --nodegroup-name "${CLUSTER_NAME}-nodes" --region "${AWS_REGION}"

echo -e "${MAGENTA}Installing AWS Load Balancer Controller...${NC}"
# Create OIDC provider
OIDC_ISSUER=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --query "cluster.identity.oidc.issuer" --output text)
OIDC_HOST="${OIDC_ISSUER#https://}"
THUMBPRINT="9e99a48a9960b14926bb7f3b02e22da2b0ab7280"

aws iam create-open-id-connect-provider \
  --url "${OIDC_ISSUER}" \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list "${THUMBPRINT}" >/dev/null || true

# Create ALB Controller policy
ALB_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-${CLUSTER_NAME}"
ALB_POLICY_DOC='{
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
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeListenerCertificates",
        "elasticloadbalancing:DescribeSSLPolicies",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetGroupAttributes",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cognito-idp:DescribeUserPoolClient",
        "acm:ListCertificates",
        "acm:DescribeCertificate",
        "iam:ListServerCertificates",
        "iam:GetServerCertificate",
        "waf-regional:GetWebACL",
        "waf-regional:GetWebACLForResource",
        "waf-regional:AssociateWebACL",
        "waf-regional:DisassociateWebACL",
        "wafv2:GetWebACL",
        "wafv2:GetWebACLForResource",
        "wafv2:AssociateWebACL",
        "wafv2:DisassociateWebACL",
        "shield:DescribeProtection",
        "shield:GetSubscriptionState",
        "shield:DescribeSubscription",
        "shield:CreateProtection",
        "shield:DeleteProtection"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSecurityGroup"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags"
      ],
      "Resource": "arn:aws:ec2:*:*:security-group/*",
      "Condition": {
        "StringEquals": {
          "ec2:CreateAction": "CreateSecurityGroup"
        },
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateTargetGroup"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:DeleteRule"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags"
      ],
      "Resource": [
        "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
        "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
      ],
      "Condition": {
        "Null": {
          "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:SetIpAddressType",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:SetSubnets",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:DeleteTargetGroup"
      ],
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets"
      ],
      "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:SetWebAcl",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:AddListenerCertificates",
        "elasticloadbalancing:RemoveListenerCertificates",
        "elasticloadbalancing:ModifyRule"
      ],
      "Resource": "*"
    }
  ]
}'

ALB_POLICY_ARN=$(aws iam create-policy \
  --policy-name "${ALB_POLICY_NAME}" \
  --policy-document "${ALB_POLICY_DOC}" \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || \
  aws iam list-policies --scope Local --query "Policies[?PolicyName=='${ALB_POLICY_NAME}'].Arn" --output text)

# Create ALB Controller role
ALB_ROLE_NAME="AmazonEKSLoadBalancerControllerRole-${CLUSTER_NAME}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

ALB_TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::'"${ACCOUNT_ID}"':oidc-provider/'"${OIDC_HOST}"'"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "'"${OIDC_HOST}"':sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
          "'"${OIDC_HOST}"':aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}'

aws iam create-role \
  --role-name "${ALB_ROLE_NAME}" \
  --assume-role-policy-document "${ALB_TRUST_POLICY}" >/dev/null || true

aws iam attach-role-policy \
  --role-name "${ALB_ROLE_NAME}" \
  --policy-arn "${ALB_POLICY_ARN}" || true

ALB_ROLE_ARN=$(aws iam get-role --role-name "${ALB_ROLE_NAME}" --query 'Role.Arn' --output text)

# Install ALB Controller
kubectl create serviceaccount -n kube-system aws-load-balancer-controller || true
kubectl annotate serviceaccount -n kube-system aws-load-balancer-controller \
  eks.amazonaws.com/role-arn="${ALB_ROLE_ARN}" --overwrite

helm repo add eks https://aws.github.io/eks-charts || true
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${AWS_REGION}" \
  --set vpcId="${VPC_ID}"

echo -e "${MAGENTA}Waiting for ALB Controller to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s

# Save cluster info
mkdir -p artifacts
cat > artifacts/cluster-info.json <<JSON
{
  "ClusterName": "${CLUSTER_NAME}",
  "Region": "${AWS_REGION}",
  "VpcId": "${VPC_ID}",
  "PublicSubnets": ["${PUB_SUBNET_1}", "${PUB_SUBNET_2}", "${PUB_SUBNET_3}"],
  "PrivateSubnets": ["${PRV_SUBNET_1}", "${PRV_SUBNET_2}", "${PRV_SUBNET_3}"],
  "ClusterRoleArn": "${CLUSTER_ROLE_ARN}",
  "NodeRoleArn": "${NODE_ROLE_ARN}",
  "AlbRoleArn": "${ALB_ROLE_ARN}"
}
JSON

cat > .env <<ENV
CLUSTER_NAME=${CLUSTER_NAME}
AWS_REGION=${AWS_REGION}
VPC_ID=${VPC_ID}
PUBLIC_SUBNETS=${PUB_SUBNET_1},${PUB_SUBNET_2},${PUB_SUBNET_3}
PRIVATE_SUBNETS=${PRV_SUBNET_1},${PRV_SUBNET_2},${PRV_SUBNET_3}
CLUSTER_ROLE_NAME=${CLUSTER_ROLE_NAME}
NODE_ROLE_NAME=${NODE_ROLE_NAME}
ALB_ROLE_NAME=${ALB_ROLE_NAME}
ENV

echo -e "${GREEN}=== EKS Cluster Creation Complete ===${NC}"
echo -e "${CYAN}Cluster Name: ${CLUSTER_NAME}${NC}"
echo -e "${CYAN}Region: ${AWS_REGION}${NC}"
echo -e "${CYAN}VPC ID: ${VPC_ID}${NC}"
echo -e "${CYAN}Ready for Kasten K10 deployment!${NC}"# Updated Sun Nov  9 12:50:08 CET 2025
# Updated Sun Nov  9 12:52:16 CET 2025
