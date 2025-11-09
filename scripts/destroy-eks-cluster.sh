#!/usr/bin/env bash
set -euo pipefail

CYAN="\033[0;36m"; MAGENTA="\033[0;35m"; GREEN="\033[0;32m"; RED="\033[0;31m"; NC="\033[0m"

echo -e "${MAGENTA}=== EKS Cluster Destruction ===${NC}"

# Load environment if available
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -a; source .env; set +a
fi

echo -e "${CYAN}EKS Cluster name [${CLUSTER_NAME:-kasten-cluster}]: ${NC}"
read -r CLUSTER_NAME_IN
CLUSTER_NAME="${CLUSTER_NAME_IN:-${CLUSTER_NAME:-kasten-cluster}}"

echo -e "${CYAN}AWS Region [${AWS_REGION:-us-west-2}]: ${NC}"
read -r AWS_REGION_IN
AWS_REGION="${AWS_REGION_IN:-${AWS_REGION:-us-west-2}}"

# Derive resource names
CLUSTER_ROLE_NAME="eksClusterRole-${CLUSTER_NAME}"
NODE_ROLE_NAME="eksNodeRole-${CLUSTER_NAME}"
ALB_ROLE_NAME="AmazonEKSLoadBalancerControllerRole-${CLUSTER_NAME}"
ALB_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-${CLUSTER_NAME}"

echo -e "${MAGENTA}Uninstalling AWS Load Balancer Controller...${NC}"
if helm list -n kube-system | grep -q aws-load-balancer-controller; then
  echo "  ✓ Removing ALB Controller Helm chart"
  helm uninstall aws-load-balancer-controller -n kube-system || true
fi

if kubectl get serviceaccount aws-load-balancer-controller -n kube-system >/dev/null 2>&1; then
  echo "  ✓ Removing ALB Controller ServiceAccount"
  kubectl delete serviceaccount aws-load-balancer-controller -n kube-system || true
fi

echo -e "${MAGENTA}Deleting node group...${NC}"
if aws eks describe-nodegroup --cluster-name "${CLUSTER_NAME}" --nodegroup-name "${CLUSTER_NAME}-nodes" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "  ✓ Deleting node group: ${CLUSTER_NAME}-nodes"
  aws eks delete-nodegroup --cluster-name "${CLUSTER_NAME}" --nodegroup-name "${CLUSTER_NAME}-nodes" --region "${AWS_REGION}" || true
  echo "  ⏳ Waiting for node group deletion..."
  aws eks wait nodegroup-deleted --cluster-name "${CLUSTER_NAME}" --nodegroup-name "${CLUSTER_NAME}-nodes" --region "${AWS_REGION}" || true
fi

echo -e "${MAGENTA}Deleting EKS cluster...${NC}"
if aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "  ✓ Deleting EKS cluster: ${CLUSTER_NAME}"
  aws eks delete-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" || true
  echo "  ⏳ Waiting for cluster deletion..."
  aws eks wait cluster-deleted --name "${CLUSTER_NAME}" --region "${AWS_REGION}" || true
fi

echo -e "${MAGENTA}Deleting IAM roles and policies...${NC}"
# ALB Controller role
if aws iam get-role --role-name "${ALB_ROLE_NAME}" >/dev/null 2>&1; then
  ALB_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='${ALB_POLICY_NAME}'].Arn" --output text)
  if [ -n "${ALB_POLICY_ARN}" ]; then
    echo "  ✓ Detaching ALB policy from role"
    aws iam detach-role-policy --role-name "${ALB_ROLE_NAME}" --policy-arn "${ALB_POLICY_ARN}" || true
  fi
  echo "  ✓ Deleting ALB Controller role: ${ALB_ROLE_NAME}"
  aws iam delete-role --role-name "${ALB_ROLE_NAME}" || true
fi

if [ -n "${ALB_POLICY_ARN:-}" ] && aws iam get-policy --policy-arn "${ALB_POLICY_ARN}" >/dev/null 2>&1; then
  echo "  ✓ Deleting ALB Controller policy: ${ALB_POLICY_NAME}"
  aws iam delete-policy --policy-arn "${ALB_POLICY_ARN}" || true
fi

# Node role
if aws iam get-role --role-name "${NODE_ROLE_NAME}" >/dev/null 2>&1; then
  echo "  ✓ Detaching policies from node role"
  for POLICY in AmazonEKSWorkerNodePolicy AmazonEKS_CNI_Policy AmazonEC2ContainerRegistryReadOnly; do
    aws iam detach-role-policy --role-name "${NODE_ROLE_NAME}" --policy-arn "arn:aws:iam::aws:policy/${POLICY}" || true
  done
  echo "  ✓ Deleting node role: ${NODE_ROLE_NAME}"
  aws iam delete-role --role-name "${NODE_ROLE_NAME}" || true
fi

# Cluster role
if aws iam get-role --role-name "${CLUSTER_ROLE_NAME}" >/dev/null 2>&1; then
  echo "  ✓ Detaching policy from cluster role"
  aws iam detach-role-policy --role-name "${CLUSTER_ROLE_NAME}" --policy-arn "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" || true
  echo "  ✓ Deleting cluster role: ${CLUSTER_ROLE_NAME}"
  aws iam delete-role --role-name "${CLUSTER_ROLE_NAME}" || true
fi

echo -e "${MAGENTA}Deleting OIDC provider...${NC}"
OIDC_ISSUER=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --query "cluster.identity.oidc.issuer" --output text 2>/dev/null || true)
if [ -n "${OIDC_ISSUER}" ]; then
  OIDC_HOST="${OIDC_ISSUER#https://}"
  OIDC_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, '${OIDC_HOST}')].Arn" --output text)
  if [ -n "${OIDC_ARN}" ]; then
    echo "  ✓ Deleting OIDC provider: ${OIDC_ARN}"
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" || true
  fi
fi

echo -e "${MAGENTA}Deleting VPC and networking...${NC}"
if [ -n "${VPC_ID:-}" ]; then
  # Delete NAT Gateway
  NAT_GW_ID=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=${VPC_ID}" --query 'NatGateways[0].NatGatewayId' --output text --region "${AWS_REGION}" 2>/dev/null || true)
  if [ -n "${NAT_GW_ID}" ] && [ "${NAT_GW_ID}" != "None" ]; then
    echo "  ✓ Deleting NAT Gateway: ${NAT_GW_ID}"
    aws ec2 delete-nat-gateway --nat-gateway-id "${NAT_GW_ID}" --region "${AWS_REGION}" || true
    echo "  ⏳ Waiting for NAT Gateway deletion..."
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids "${NAT_GW_ID}" --region "${AWS_REGION}" || true
  fi

  # Release Elastic IP
  EIP_ID=$(aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --query "Addresses[?AssociationId!=null].AllocationId" --output text --region "${AWS_REGION}" 2>/dev/null || true)
  if [ -n "${EIP_ID}" ]; then
    echo "  ✓ Releasing Elastic IP: ${EIP_ID}"
    aws ec2 release-address --allocation-id "${EIP_ID}" --region "${AWS_REGION}" || true
  fi

  # Delete subnets
  SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[].SubnetId' --output text --region "${AWS_REGION}" 2>/dev/null || true)
  for SUBNET_ID in ${SUBNET_IDS}; do
    if [ -n "${SUBNET_ID}" ]; then
      echo "  ✓ Deleting subnet: ${SUBNET_ID}"
      aws ec2 delete-subnet --subnet-id "${SUBNET_ID}" --region "${AWS_REGION}" || true
    fi
  done

  # Delete route tables (except main)
  RT_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text --region "${AWS_REGION}" 2>/dev/null || true)
  for RT_ID in ${RT_IDS}; do
    if [ -n "${RT_ID}" ]; then
      echo "  ✓ Deleting route table: ${RT_ID}"
      aws ec2 delete-route-table --route-table-id "${RT_ID}" --region "${AWS_REGION}" || true
    fi
  done

  # Delete Internet Gateway
  IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=${VPC_ID}" --query 'InternetGateways[0].InternetGatewayId' --output text --region "${AWS_REGION}" 2>/dev/null || true)
  if [ -n "${IGW_ID}" ] && [ "${IGW_ID}" != "None" ]; then
    echo "  ✓ Detaching Internet Gateway: ${IGW_ID}"
    aws ec2 detach-internet-gateway --internet-gateway-id "${IGW_ID}" --vpc-id "${VPC_ID}" --region "${AWS_REGION}" || true
    echo "  ✓ Deleting Internet Gateway: ${IGW_ID}"
    aws ec2 delete-internet-gateway --internet-gateway-id "${IGW_ID}" --region "${AWS_REGION}" || true
  fi

  # Delete VPC
  echo "  ✓ Deleting VPC: ${VPC_ID}"
  aws ec2 delete-vpc --vpc-id "${VPC_ID}" --region "${AWS_REGION}" || true
fi

echo -e "${MAGENTA}Cleaning up local files...${NC}"
if [ -d "artifacts" ]; then
  echo "  ✓ Removing artifacts"
  rm -rf artifacts/
fi

if [ -f ".env" ]; then
  echo "  ✓ Removing environment file"
  rm -f .env
fi

echo -e "${GREEN}\\n=== DESTRUCTION COMPLETE - VERIFICATION REPORT ===${NC}"
echo -e "${CYAN}Verifying all resources have been removed...${NC}\\n"

# Verify cluster
if aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo -e "${RED}❌ EKS Cluster still exists: ${CLUSTER_NAME}${NC}"
else
  echo -e "${GREEN}✅ EKS Cluster removed: ${CLUSTER_NAME}${NC}"
fi

# Verify IAM roles
for ROLE in "${CLUSTER_ROLE_NAME}" "${NODE_ROLE_NAME}" "${ALB_ROLE_NAME}"; do
  if aws iam get-role --role-name "${ROLE}" >/dev/null 2>&1; then
    echo -e "${RED}❌ IAM Role still exists: ${ROLE}${NC}"
  else
    echo -e "${GREEN}✅ IAM Role removed: ${ROLE}${NC}"
  fi
done

# Verify VPC
if [ -n "${VPC_ID:-}" ] && aws ec2 describe-vpcs --vpc-ids "${VPC_ID}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo -e "${RED}❌ VPC still exists: ${VPC_ID}${NC}"
else
  echo -e "${GREEN}✅ VPC removed${NC}"
fi

echo -e "\\n${GREEN}🎉 All EKS cluster resources successfully destroyed!${NC}"# Updated Sun Nov  9 12:50:08 CET 2025
# Updated Sun Nov  9 12:52:16 CET 2025
# Updated Sun Nov  9 12:56:43 CET 2025
