#!/usr/bin/env bash
set -euo pipefail

CYAN="\033[0;36m"; MAGENTA="\033[0;35m"; GREEN="\033[0;32m"; RED="\033[0;31m"; NC="\033[0m"

echo -e "${MAGENTA}=== Kasten K10 Deployment on EKS ===${NC}"

# Interactive inputs
echo -e "${CYAN}EKS Cluster name: ${NC}"
read CLUSTER_NAME
echo -e "${CYAN}AWS Region [us-west-2]: ${NC}"
read AWS_REGION
AWS_REGION="${AWS_REGION:-us-west-2}"

echo -e "${CYAN}Kasten namespace [kasten-io]: ${NC}"
read K10_NAMESPACE
K10_NAMESPACE="${K10_NAMESPACE:-kasten-io}"

echo -e "${CYAN}Domain for HTTPS access (e.g., k10.example.com): ${NC}"
read DOMAIN_NAME

echo -e "${CYAN}S3 Bucket name for backups: ${NC}"
read S3_BUCKET

echo -e "${CYAN}Country code for SSL cert [US]: ${NC}"
read CERT_COUNTRY
CERT_COUNTRY="${CERT_COUNTRY:-US}"

echo -e "${CYAN}State for SSL cert [California]: ${NC}"
read CERT_STATE
CERT_STATE="${CERT_STATE:-California}"

echo -e "${CYAN}City for SSL cert [San Francisco]: ${NC}"
read CERT_CITY
CERT_CITY="${CERT_CITY:-San Francisco}"

echo -e "${CYAN}Organization for SSL cert [MyOrg]: ${NC}"
read CERT_ORG
CERT_ORG="${CERT_ORG:-MyOrg}"

echo -e "${MAGENTA}Updating kubeconfig for cluster ${CLUSTER_NAME}...${NC}"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

echo -e "${MAGENTA}Creating namespace ${K10_NAMESPACE}...${NC}"
kubectl create namespace "${K10_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo -e "${MAGENTA}Generating self-signed SSL certificate...${NC}"
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/tls.key \
  -out certs/tls.crt \
  -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/CN=${DOMAIN_NAME}"

echo -e "${MAGENTA}Creating TLS secret...${NC}"
kubectl create secret tls k10-tls-secret \
  --cert=certs/tls.crt \
  --key=certs/tls.key \
  -n "${K10_NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${MAGENTA}Adding Kasten Helm repository...${NC}"
helm repo add kasten https://charts.kasten.io/
helm repo update

echo -e "${MAGENTA}Creating IAM policy for Kasten K10...${NC}"
POLICY_NAME="KastenK10Policy"
POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:ListBucketMultipartUploads",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": [
        "arn:aws:s3:::'"${S3_BUCKET}"'",
        "arn:aws:s3:::'"${S3_BUCKET}"'/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSnapshots",
        "ec2:DescribeVolumes",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    }
  ]
}'

POLICY_ARN=$(aws iam create-policy \
  --policy-name "${POLICY_NAME}" \
  --policy-document "${POLICY_DOC}" \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || \
  aws iam list-policies \
  --scope Local \
  --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" \
  --output text)

echo -e "${MAGENTA}Creating IAM role for Kasten K10...${NC}"
ROLE_NAME="KastenK10Role"
OIDC_ISSUER=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --query "cluster.identity.oidc.issuer" --output text)
OIDC_HOST=$(echo "${OIDC_ISSUER}" | sed -e 's~https://~~')
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

TRUST_POLICY='{
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
          "'"${OIDC_HOST}"':sub": "system:serviceaccount:'"${K10_NAMESPACE}"':k10-k10",
          "'"${OIDC_HOST}"':aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}'

aws iam create-role \
  --role-name "${ROLE_NAME}" \
  --assume-role-policy-document "${TRUST_POLICY}" >/dev/null 2>&1 || true

aws iam attach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "${POLICY_ARN}" || true

ROLE_ARN=$(aws iam get-role --role-name "${ROLE_NAME}" --query 'Role.Arn' --output text)

echo -e "${MAGENTA}Installing Kasten K10 with Helm...${NC}"
helm upgrade --install k10 kasten/k10 \
  --namespace="${K10_NAMESPACE}" \
  --set auth.tokenAuth.enabled=true \
  --set ingress.create=true \
  --set ingress.host="${DOMAIN_NAME}" \
  --set ingress.tls.enabled=true \
  --set ingress.tls.secretName=k10-tls-secret \
  --set persistence.storageClass=gp2-immediate \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ROLE_ARN}"

echo -e "${MAGENTA}Creating cluster role binding for gateway service account...${NC}"
kubectl create clusterrolebinding k10-admin --clusterrole=cluster-admin --serviceaccount="${K10_NAMESPACE}":gateway --dry-run=client -o yaml | kubectl apply -f -

echo -e "${MAGENTA}Creating LoadBalancer service for external access...${NC}"
kubectl patch svc gateway -n "${K10_NAMESPACE}" -p '{"spec":{"type":"LoadBalancer"}}' || true

echo -e "${MAGENTA}Waiting for K10 pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=k10 -n "${K10_NAMESPACE}" --timeout=600s || echo "Some pods may still be starting - this is normal"

echo -e "${MAGENTA}S3 location profile will be configured manually in Kasten dashboard...${NC}"
echo "Note: Configure S3 backup location in Kasten UI using bucket: ${S3_BUCKET}"

echo -e "${MAGENTA}Getting K10 dashboard token...${NC}"
TOKEN=$(kubectl create token gateway -n "${K10_NAMESPACE}" --duration=24h)

echo -e "${MAGENTA}Creating LoadBalancer service for external access...${NC}"
kubectl patch svc gateway -n "${K10_NAMESPACE}" -p '{"spec":{"type":"LoadBalancer"}}' || true

echo -e "${MAGENTA}Getting external LoadBalancer URL...${NC}"
echo "  ⏳ Waiting for LoadBalancer to get external IP..."
for i in {1..20}; do
  EXTERNAL_URL=$(kubectl get svc gateway -n "${K10_NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  if [ -n "${EXTERNAL_URL}" ]; then
    break
  fi
  echo "    Waiting... (${i}/20)"
  sleep 15
done

if [ -z "${EXTERNAL_URL}" ]; then
  echo -e "${RED}Failed to get LoadBalancer URL. Checking service status:${NC}"
  kubectl get svc gateway -n "${K10_NAMESPACE}"
  EXTERNAL_URL="<pending>"
fi

# Also try to get ALB DNS if ingress exists
ALB_DNS=$(kubectl get ingress -n "${K10_NAMESPACE}" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

mkdir -p artifacts
cat > artifacts/kasten-info.json <<JSON
{
  "ClusterName": "${CLUSTER_NAME}",
  "Region": "${AWS_REGION}",
  "Namespace": "${K10_NAMESPACE}",
  "Domain": "${DOMAIN_NAME}",
  "S3Bucket": "${S3_BUCKET}",
  "RoleArn": "${ROLE_ARN}",
  "PolicyArn": "${POLICY_ARN}",
  "AlbDnsName": "${ALB_DNS}",
  "LoadBalancerUrl": "${EXTERNAL_URL}",
  "DashboardToken": "${TOKEN}"
}
JSON

cat > .env <<ENV
CLUSTER_NAME=${CLUSTER_NAME}
AWS_REGION=${AWS_REGION}
K10_NAMESPACE=${K10_NAMESPACE}
DOMAIN_NAME=${DOMAIN_NAME}
S3_BUCKET=${S3_BUCKET}
ROLE_ARN=${ROLE_ARN}
POLICY_ARN=${POLICY_ARN}
ALB_DNS=${ALB_DNS}
EXTERNAL_URL=${EXTERNAL_URL}
DASHBOARD_TOKEN=${TOKEN}
ENV

echo -e "${GREEN}=== Kasten K10 Deployment Complete ===${NC}"
echo -e "${CYAN}=== ACCESS INFORMATION ===${NC}"
if [ -n "${EXTERNAL_URL}" ] && [ "${EXTERNAL_URL}" != "<pending>" ]; then
  echo -e "${GREEN}✅ LoadBalancer URL: http://${EXTERNAL_URL}/k10/#/${NC}"
else
  echo -e "${RED}❌ LoadBalancer URL: Pending (check 'kubectl get svc gateway -n kasten-io')${NC}"
fi
if [ -n "${ALB_DNS}" ]; then
  echo -e "${GREEN}✅ ALB URL: https://${ALB_DNS}/k10/#/${NC}"
  echo -e "${CYAN}Note: Add DNS record: ${DOMAIN_NAME} -> ${ALB_DNS}${NC}"
else
  echo -e "${RED}❌ ALB URL: Not available${NC}"
fi
echo -e "${CYAN}Dashboard Token: ${TOKEN}${NC}"
echo -e "${CYAN}Certificate files: certs/${NC}"

echo -e "${MAGENTA}=== NEXT STEPS ===${NC}"
echo -e "${CYAN}1. Open the LoadBalancer URL in your browser${NC}"
echo -e "${CYAN}2. Use the dashboard token above for authentication${NC}"
echo -e "${CYAN}3. Configure S3 backup location in Kasten dashboard${NC}"
echo -e "${CYAN}4. Create backup policies for your applications${NC}"
echo -e "${CYAN}5. To get a new token anytime: kubectl create token gateway -n kasten-io --duration=24h${NC}"

echo -e "${GREEN}🎉 Kasten K10 is ready for backup and disaster recovery!${NC}"