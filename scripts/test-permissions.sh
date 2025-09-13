#!/usr/bin/env bash

echo "Testing AWS permissions..."

echo "1. Testing AWS identity:"
aws sts get-caller-identity

echo -e "\n2. Testing EKS permissions:"
aws eks list-clusters --region us-west-2

echo -e "\n3. Testing IAM permissions:"
aws iam list-roles --max-items 1 >/dev/null && echo "IAM read: OK" || echo "IAM read: FAILED"

echo -e "\n4. Testing EC2 permissions:"
aws ec2 describe-vpcs --region us-west-2 --max-items 1 >/dev/null && echo "EC2 read: OK" || echo "EC2 read: FAILED"

echo -e "\n5. Testing if cluster already exists:"
aws eks describe-cluster --name kasten-cluster --region us-west-2 2>/dev/null && echo "Cluster EXISTS" || echo "Cluster does not exist"

echo -e "\n6. Testing cluster creation with minimal config:"
# Get actual account ID and create valid test ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEST_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/eksServiceRole"

# Get first available subnet
TEST_SUBNET=$(aws ec2 describe-subnets --query 'Subnets[0].SubnetId' --output text 2>/dev/null || echo "subnet-12345")

echo "Using test role: ${TEST_ROLE_ARN}"
echo "Using test subnet: ${TEST_SUBNET}"
aws eks create-cluster --name test-cluster-permissions --version 1.29 --role-arn "${TEST_ROLE_ARN}" --resources-vpc-config subnetIds="${TEST_SUBNET}" --region us-west-2 --dry-run 2>&1 || echo "This shows what error we'd get"