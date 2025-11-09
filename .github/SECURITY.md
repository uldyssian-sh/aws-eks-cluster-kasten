# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability, please follow these steps:

### 1. Do NOT create a public GitHub issue

Security vulnerabilities should not be reported through public GitHub issues.

### 2. Report privately

Please report security vulnerabilities by creating a private security advisory:

1. Go to the [Security tab](https://github.com/uldyssian-sh/aws-eks-cluster-kasten/security)
2. Click "Report a vulnerability"
3. Fill out the security advisory form with detailed information

### 3. Include the following information

- Type of vulnerability
- Full paths of source file(s) related to the vulnerability
- Location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

### 4. Response timeline

- **Initial response**: Within 48 hours
- **Status update**: Within 7 days
- **Resolution**: Varies based on complexity, typically within 30 days

## Security Best Practices

When using this project, please follow these security best practices:

### AWS Security
- Use IAM roles with least privilege principle
- Enable AWS CloudTrail for audit logging
- Use AWS Secrets Manager for sensitive data
- Enable encryption at rest and in transit
- Regularly rotate access keys and credentials

### Kubernetes Security
- Use RBAC for access control
- Enable network policies
- Scan container images for vulnerabilities
- Use Pod Security Standards
- Regularly update Kubernetes versions

### Kasten K10 Security
- Enable authentication and authorization
- Use HTTPS for dashboard access
- Regularly backup encryption keys
- Monitor backup and restore activities
- Keep Kasten K10 updated to latest version

### Infrastructure Security
- Use private subnets for worker nodes
- Enable VPC Flow Logs
- Implement security groups with minimal required access
- Use AWS Systems Manager for secure access
- Enable GuardDuty for threat detection

## Security Features

This project includes the following security features:

- **Encryption**: EBS volumes and S3 buckets encrypted by default
- **Network Security**: Private subnets and security groups configured
- **Access Control**: IAM roles with minimal required permissions
- **Monitoring**: CloudWatch logging and monitoring enabled
- **Compliance**: Follows AWS and Kubernetes security best practices

## Security Scanning

We use automated security scanning tools:

- **GitHub Security Advisories**: Dependency vulnerability scanning
- **CodeQL**: Static code analysis
- **Dependabot**: Automated dependency updates
- **Custom Security Workflows**: Infrastructure and configuration validation

## Compliance

This project aims to comply with:

- AWS Well-Architected Framework Security Pillar
- CIS Kubernetes Benchmark
- NIST Cybersecurity Framework
- SOC 2 Type II controls (where applicable)

## Security Updates

Security updates are released as soon as possible after a vulnerability is confirmed and a fix is available. Updates are communicated through:

- GitHub Security Advisories
- Release notes
- Repository notifications

## Contact

For security-related questions or concerns, please contact:

- **Security Team**: Create a private security advisory
- **General Questions**: Open a regular GitHub issue (for non-security topics)

## Acknowledgments

We appreciate the security research community and will acknowledge researchers who responsibly disclose vulnerabilities (with their permission).

---

**Note**: This security policy is subject to change. Please check back regularly for updates.# Updated Sun Nov  9 12:50:08 CET 2025
# Updated Sun Nov  9 12:52:16 CET 2025
# Updated Sun Nov  9 12:56:43 CET 2025
