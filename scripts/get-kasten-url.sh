#!/usr/bin/env bash
set -euo pipefail

CYAN="\033[0;36m"; MAGENTA="\033[0;35m"; GREEN="\033[0;32m"; RED="\033[0;31m"; NC="\033[0m"

echo -e "${MAGENTA}=== Getting Kasten K10 External URL ===${NC}"

# Check if Kasten is deployed
if ! kubectl get namespace kasten-io >/dev/null 2>&1; then
    echo -e "${RED}Kasten K10 is not deployed. Run ./scripts/deploy-kasten.sh first.${NC}"
    exit 1
fi

echo -e "${MAGENTA}Creating LoadBalancer service for external access...${NC}"
kubectl patch svc gateway -n kasten-io -p '{"spec":{"type":"LoadBalancer"}}'

echo -e "${MAGENTA}Waiting for external IP (this may take 2-3 minutes)...${NC}"
for i in {1..20}; do
    EXTERNAL_IP=$(kubectl get svc gateway -n kasten-io -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "${EXTERNAL_IP}" ]; then
        break
    fi
    echo "  Waiting... (${i}/20)"
    sleep 15
done

if [ -z "${EXTERNAL_IP}" ]; then
    echo -e "${RED}Failed to get external IP. Checking service status:${NC}"
    kubectl get svc gateway -n kasten-io
    exit 1
fi

echo -e "${GREEN}=== Kasten K10 Dashboard Access ===${NC}"
echo -e "${CYAN}External URL: http://${EXTERNAL_IP}/k10/#/${NC}"
echo -e "${CYAN}Note: Use HTTP (not HTTPS) for this LoadBalancer URL${NC}"

echo -e "${MAGENTA}Getting authentication token...${NC}"
if ! TOKEN=$(kubectl create token gateway -n kasten-io --duration=24h 2>/dev/null); then
  echo -e "${RED}Failed to create token. Check if gateway service account exists.${NC}"
  exit 1
fi
echo -e "${CYAN}Token: ${TOKEN}${NC}"
echo -e "${CYAN}To get a new token: kubectl create token gateway -n kasten-io --duration=24h${NC}"

# Save URL to file
mkdir -p artifacts
cat > artifacts/kasten-access.txt <<EOF
Kasten K10 Dashboard Access:
URL: http://${EXTERNAL_IP}/k10/#/
Token: ${TOKEN}
Date: $(date)
EOF

echo -e "${GREEN}URL saved to: artifacts/kasten-access.txt${NC}"# Updated Sun Nov  9 12:50:08 CET 2025
