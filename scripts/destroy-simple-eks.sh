#!/usr/bin/env bash
set -euo pipefail

CYAN="\033[0;36m"; MAGENTA="\033[0;35m"; GREEN="\033[0;32m"; RED="\033[0;31m"; NC="\033[0m"

echo -e "${MAGENTA}=== Simple EKS Cluster Destruction ===${NC}"

if [ -f .env ]; then
  set -a; source .env; set +a
fi

echo -e "${CYAN}Cluster name [${CLUSTER_NAME:-kasten-eks}]: ${NC}"
read CLUSTER_NAME_IN
CLUSTER_NAME="${CLUSTER_NAME_IN:-${CLUSTER_NAME:-kasten-eks}}"

echo -e "${CYAN}AWS Region [${AWS_REGION:-us-west-2}]: ${NC}"
read AWS_REGION_IN
AWS_REGION="${AWS_REGION_IN:-${AWS_REGION:-us-west-2}}"

echo -e "${MAGENTA}Uninstalling AWS Load Balancer Controller...${NC}"
helm uninstall aws-load-balancer-controller -n kube-system || true

echo -e "${MAGENTA}Removing EBS CSI Driver addon...${NC}"
eksctl delete addon --name aws-ebs-csi-driver --cluster="${CLUSTER_NAME}" --region="${AWS_REGION}" || true

echo -e "${MAGENTA}Cleaning up ALB Controller IAM resources...${NC}"
ALB_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy-${CLUSTER_NAME}'].Arn" --output text 2>/dev/null || true)
if [ -n "${ALB_POLICY_ARN}" ] && [ "${ALB_POLICY_ARN}" != "None" ]; then
  aws iam delete-policy --policy-arn "${ALB_POLICY_ARN}" || true
fi

echo -e "${MAGENTA}Deleting EKS cluster with eksctl...${NC}"
eksctl delete cluster --name="${CLUSTER_NAME}" --region="${AWS_REGION}"

echo -e "${MAGENTA}Cleaning up local files...${NC}"
rm -f .env
rm -rf artifacts/

echo -e "${GREEN}=== EKS Cluster Destroyed ===${NC}"

echo -e "\n${MAGENTA}=== FINAL VERIFICATION REPORT ===${NC}"
echo -e "${CYAN}Checking remaining AWS resources...${NC}"

# Check remaining resources
REMAINING_CLUSTERS=$(aws eks list-clusters --region "${AWS_REGION}" --query 'clusters' --output text 2>/dev/null || true)
REMAINING_CF_STACKS=$(aws cloudformation list-stacks --region "${AWS_REGION}" --query 'StackSummaries[?contains(StackName, `eksctl-${CLUSTER_NAME}`) && StackStatus != `DELETE_COMPLETE`].StackName' --output text 2>/dev/null || true)
REMAINING_ALB_POLICIES=$(aws iam list-policies --scope Local --query 'Policies[?contains(PolicyName, `LoadBalancer`) && contains(PolicyName, `${CLUSTER_NAME}`)].PolicyName' --output text 2>/dev/null || true)

if [ -z "${REMAINING_CLUSTERS}" ] || [ "${REMAINING_CLUSTERS}" = "None" ]; then
  echo -e "${GREEN}✅ EKS Clusters: 0 remaining${NC}"
else
  echo -e "${RED}❌ EKS Clusters: ${REMAINING_CLUSTERS}${NC}"
fi

if [ -z "${REMAINING_CF_STACKS}" ] || [ "${REMAINING_CF_STACKS}" = "None" ]; then
  echo -e "${GREEN}✅ CloudFormation Stacks: 0 remaining${NC}"
else
  echo -e "${RED}❌ CloudFormation Stacks: ${REMAINING_CF_STACKS}${NC}"
fi

if [ -z "${REMAINING_ALB_POLICIES}" ] || [ "${REMAINING_ALB_POLICIES}" = "None" ]; then
  echo -e "${GREEN}✅ ALB IAM Policies: 0 remaining${NC}"
else
  echo -e "${RED}❌ ALB IAM Policies: ${REMAINING_ALB_POLICIES}${NC}"
fi

echo -e "${GREEN}\n🎯 All AWS resources cleared successfully!${NC}"
echo -e "${CYAN}No ongoing charges from this deployment.${NC}"