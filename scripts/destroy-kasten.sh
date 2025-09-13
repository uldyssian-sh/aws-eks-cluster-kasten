#!/usr/bin/env bash
set -euo pipefail

CYAN="\033[0;36m"; MAGENTA="\033[0;35m"; GREEN="\033[0;32m"; RED="\033[0;31m"; NC="\033[0m"

echo -e "${MAGENTA}=== Kasten K10 Destruction ===${NC}"

# Load environment if available
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -a; source .env; set +a
fi

echo -e "${CYAN}EKS Cluster name [${CLUSTER_NAME:-}]: ${NC}"
read -r CLUSTER_NAME_IN
CLUSTER_NAME="${CLUSTER_NAME_IN:-${CLUSTER_NAME}}"
if [[ -z "${CLUSTER_NAME}" ]]; then
  echo -e "${RED}Error: Cluster name is required${NC}"
  exit 1
fi

echo -e "${CYAN}AWS Region [${AWS_REGION:-us-west-2}]: ${NC}"
read -r AWS_REGION_IN
AWS_REGION="${AWS_REGION_IN:-${AWS_REGION:-us-west-2}}"

echo -e "${CYAN}Kasten namespace [${K10_NAMESPACE:-kasten-io}]: ${NC}"
read -r K10_NAMESPACE_IN
K10_NAMESPACE="${K10_NAMESPACE_IN:-${K10_NAMESPACE:-kasten-io}}"

# Derive resource names
ROLE_NAME="KastenK10Role"
POLICY_NAME="KastenK10Policy"

echo -e "${MAGENTA}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}" || true

echo -e "${MAGENTA}Uninstalling Kasten K10 Helm chart...${NC}"
if helm list -n "${K10_NAMESPACE}" | grep -q k10; then
  echo "  ✓ Removing Helm release: k10"
  helm uninstall k10 -n "${K10_NAMESPACE}" || true
else
  echo "  - Helm release not found (already removed)"
fi

echo -e "${MAGENTA}Deleting Kasten namespace...${NC}"
if kubectl get namespace "${K10_NAMESPACE}" >/dev/null 2>&1; then
  echo "  ✓ Deleting namespace: ${K10_NAMESPACE}"
  kubectl delete namespace "${K10_NAMESPACE}" --ignore-not-found=true || true
  echo "  ⏳ Waiting for namespace deletion..."
  kubectl wait --for=delete namespace/"${K10_NAMESPACE}" --timeout=120s || true
else
  echo "  - Namespace not found (already removed)"
fi

echo -e "${MAGENTA}Deleting IAM roles and policies...${NC}"

# Delete KastenK10Role
if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  echo "  ✓ Detaching policies from role: ${ROLE_NAME}"
  # Get all attached policies
  ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "${ROLE_NAME}" --query 'AttachedPolicies[].PolicyArn' --output text)
  for POLICY_ARN in ${ATTACHED_POLICIES}; do
    if [ -n "${POLICY_ARN}" ]; then
      echo "    - Detaching policy: ${POLICY_ARN}"
      aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn "${POLICY_ARN}" || true
    fi
  done
  echo "  ✓ Deleting IAM role: ${ROLE_NAME}"
  aws iam delete-role --role-name "${ROLE_NAME}" || true
else
  echo "  - IAM role not found: ${ROLE_NAME} (already removed)"
fi

# Delete KastenK10Policy
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" --output text 2>/dev/null || true)
if [ -n "${POLICY_ARN}" ] && aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
  echo "  ✓ Deleting IAM policy: ${POLICY_NAME}"
  aws iam delete-policy --policy-arn "${POLICY_ARN}" || true
else
  echo "  - IAM policy not found (already removed)"
fi

# Only clean up Kasten-specific roles, not EKS system roles
echo "  ✓ Checking for additional Kasten roles..."
KASTEN_ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, \`Kasten\`) && !contains(RoleName, \`EKS\`) && !contains(RoleName, \`LoadBalancer\`) && !contains(RoleName, \`eksctl\`)].RoleName" --output text 2>/dev/null || true)
for KASTEN_ROLE in ${KASTEN_ROLES}; do
  if [ -n "${KASTEN_ROLE}" ] && [ "${KASTEN_ROLE}" != "None" ]; then
    echo "    - Found Kasten role: ${KASTEN_ROLE}"
    # Detach all policies
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "${KASTEN_ROLE}" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || true)
    for POLICY_ARN in ${ATTACHED_POLICIES}; do
      if [ -n "${POLICY_ARN}" ] && [ "${POLICY_ARN}" != "None" ]; then
        aws iam detach-role-policy --role-name "${KASTEN_ROLE}" --policy-arn "${POLICY_ARN}" || true
      fi
    done
    # Delete role
    aws iam delete-role --role-name "${KASTEN_ROLE}" || true
  fi
done

# Clean up only Kasten-specific policies
echo "  ✓ Checking for additional Kasten policies..."
KASTEN_POLICIES=$(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, \`Kasten\`) && !contains(PolicyName, \`LoadBalancer\`)].Arn" --output text 2>/dev/null || true)
if [ -n "${KASTEN_POLICIES}" ] && [ "${KASTEN_POLICIES}" != "None" ]; then
  for POLICY_ARN in ${KASTEN_POLICIES}; do
    if [ -n "${POLICY_ARN}" ] && [ "${POLICY_ARN}" != "None" ]; then
      POLICY_NAME=$(aws iam get-policy --policy-arn "${POLICY_ARN}" --query 'Policy.PolicyName' --output text 2>/dev/null || echo "unknown")
      echo "    - Found Kasten policy: ${POLICY_NAME}"
      aws iam delete-policy --policy-arn "${POLICY_ARN}" || true
    fi
  done
fi

echo -e "${MAGENTA}Cleaning up cluster role bindings...${NC}"
kubectl delete clusterrolebinding k10-admin --ignore-not-found=true || true

echo -e "${MAGENTA}Cleaning up storage class...${NC}"
kubectl delete storageclass gp2-immediate --ignore-not-found=true || true

echo -e "${MAGENTA}Cleaning up local files...${NC}"
if [ -d "certs" ]; then
  echo "  ✓ Removing SSL certificates"
  rm -rf certs/
fi

if [ -d "manifests" ]; then
  echo "  ✓ Removing manifest files"
  rm -rf manifests/
fi

if [ -d "artifacts" ]; then
  echo "  ✓ Removing artifacts"
  rm -rf artifacts/
fi

if [ -f ".env" ]; then
  echo "  ✓ Removing environment file"
  rm -f .env
fi

echo -e "${GREEN}\n=== DESTRUCTION COMPLETE - VERIFICATION REPORT ===${NC}"
echo -e "${CYAN}Verifying all resources have been removed...${NC}\n"

# Verify namespace
if kubectl get namespace "${K10_NAMESPACE}" >/dev/null 2>&1; then
  echo -e "${RED}❌ Namespace still exists: ${K10_NAMESPACE}${NC}"
else
  echo -e "${GREEN}✅ Namespace removed: ${K10_NAMESPACE}${NC}"
fi

# Verify Helm release
if helm list -n "${K10_NAMESPACE}" 2>/dev/null | grep -q k10; then
  echo -e "${RED}❌ Helm release still exists: k10${NC}"
else
  echo -e "${GREEN}✅ Helm release removed: k10${NC}"
fi

# Verify IAM role
if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  echo -e "${RED}❌ IAM role still exists: ${ROLE_NAME}${NC}"
else
  echo -e "${GREEN}✅ IAM role removed: ${ROLE_NAME}${NC}"
fi

# Verify IAM policy
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" --output text 2>/dev/null || true)
if [ -n "${POLICY_ARN}" ] && aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
  echo -e "${RED}❌ IAM policy still exists: ${POLICY_NAME}${NC}"
else
  echo -e "${GREEN}✅ IAM policy removed: ${POLICY_NAME}${NC}"
fi

echo -e "\n${GREEN}🎉 All Kasten K10 resources successfully destroyed!${NC}"

echo -e "\n${MAGENTA}=== FINAL VERIFICATION REPORT ===${NC}"
echo -e "${CYAN}Checking remaining Kasten resources...${NC}"

# Check for any remaining Kasten IAM resources
REMAINING_KASTEN_ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, \`Kasten\`) && !contains(RoleName, \`EKS\`) && !contains(RoleName, \`LoadBalancer\`)].RoleName" --output text 2>/dev/null || true)
REMAINING_KASTEN_POLICIES=$(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, \`Kasten\`) && !contains(PolicyName, \`LoadBalancer\`)].PolicyName" --output text 2>/dev/null || true)

if [ -z "${REMAINING_KASTEN_ROLES}" ] || [ "${REMAINING_KASTEN_ROLES}" = "None" ]; then
  echo -e "${GREEN}✅ Kasten IAM Roles: 0 remaining${NC}"
else
  echo -e "${RED}❌ Kasten IAM Roles: ${REMAINING_KASTEN_ROLES}${NC}"
fi

if [ -z "${REMAINING_KASTEN_POLICIES}" ] || [ "${REMAINING_KASTEN_POLICIES}" = "None" ]; then
  echo -e "${GREEN}✅ Kasten IAM Policies: 0 remaining${NC}"
else
  echo -e "${RED}❌ Kasten IAM Policies: ${REMAINING_KASTEN_POLICIES}${NC}"
fi

echo -e "${GREEN}\n🎯 Kasten K10 cleanup completed successfully!${NC}"