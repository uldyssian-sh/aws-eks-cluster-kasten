# Kasten API Integration

## Overview
This document provides comprehensive guidance for integrating with Kasten K10 APIs for automated backup and disaster recovery operations.

## API Endpoints
- REST API: `https://k10-dashboard.kasten-io.svc.cluster.local/k10/api/v1`
- GraphQL API: `https://k10-dashboard.kasten-io.svc.cluster.local/k10/api/v1/graphql`

## Authentication
```bash
# Get API token
kubectl create token k10-k10 -n kasten-io
```

## Common Operations
- Policy management
- Backup execution
- Restore operations
- Monitoring and alerts

## Examples
```python
import requests

# Get backup policies
response = requests.get(
    "https://k10-dashboard/k10/api/v1/policies",
    headers={"Authorization": "Bearer <token>"}
)
```

Maintained by: uldyssian-sh