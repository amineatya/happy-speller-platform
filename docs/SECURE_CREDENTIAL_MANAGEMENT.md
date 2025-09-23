# 🔐 Secure Credential Management Guide

This guide explains how to securely manage credentials in the Happy Speller Platform project, replacing the previous hardcoded credential approach with a secure environment-based system.

## 🚨 Security Upgrade Notice

**IMPORTANT**: This project has been upgraded to use secure credential management. The old system with hardcoded credentials in Groovy scripts has been deprecated for security reasons.

### What Changed:
- ❌ **OLD**: Hardcoded credentials in `.groovy` files
- ✅ **NEW**: Environment variables with secure loading and validation

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Initial Setup](#initial-setup)
3. [Environment Variables](#environment-variables)
4. [Credential Loading](#credential-loading)
5. [Jenkins Integration](#jenkins-integration)
6. [Terraform Integration](#terraform-integration)
7. [Security Best Practices](#security-best-practices)
8. [Credential Rotation](#credential-rotation)
9. [Backup and Recovery](#backup-and-recovery)
10. [Troubleshooting](#troubleshooting)
11. [Migration from Old System](#migration-from-old-system)

## 🚀 Quick Start

### 1. Set up your credentials
```bash
# Copy the template
cp .env.example .env

# Edit with your actual values
nano .env  # or your preferred editor

# Secure the file
chmod 600 .env
```

### 2. Load and validate credentials
```bash
# Source the credential management utility
source scripts/secure-credentials.sh

# Initialize and validate
init_secure_credentials
```

### 3. Use with Jenkins
```bash
# Set environment variables for Jenkins
export GITEA_TOKEN="your_actual_gitea_token"
export MINIO_ACCESS_KEY="your_minio_access_key"
export MINIO_SECRET_KEY="your_minio_secret_key"

# Run the secure Jenkins credential setup
# Then paste secure-jenkins-credentials.groovy into Jenkins Script Console
```

### 4. Use with Terraform
```bash
# Load credentials
source scripts/secure-credentials.sh
init_secure_credentials

# Run Terraform securely
./scripts/secure-terraform.sh plan
./scripts/secure-terraform.sh apply
```

## 🔧 Initial Setup

### Step 1: Create Your Environment File

```bash
# Copy the template
cp .env.example .env

# The .env file should contain your actual credentials
# NEVER commit this file to version control!
```

### Step 2: Set Proper Permissions

```bash
# Restrict access to the .env file
chmod 600 .env

# Verify .env is in .gitignore
grep "^\.env$" .gitignore || echo ".env" >> .gitignore
```

### Step 3: Validate Your Setup

```bash
source scripts/secure-credentials.sh
check_secure_environment
```

## 🌍 Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GITEA_TOKEN` | Gitea API token for repository access | `9b407fc263328ce9f89b41721d80b48a306ece8d` |
| `MINIO_ACCESS_KEY` | MinIO access key | `minioadmin` |
| `MINIO_SECRET_KEY` | MinIO secret key | `your-secret-key` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JENKINS_TOKEN` | Jenkins API token | - |
| `GRAFANA_API_KEY` | Grafana API key | - |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | - |
| `KUBERNETES_API_SERVER` | Kubernetes API endpoint | `https://192.168.50.226:6443` |

### Terraform Variables

For Terraform, use the `TF_VAR_` prefix:

| Variable | Description |
|----------|-------------|
| `TF_VAR_minio_access_key` | MinIO access key for Terraform |
| `TF_VAR_minio_secret_key` | MinIO secret key for Terraform |
| `TF_VAR_grafana_admin_password` | Grafana admin password for Terraform |

## 🔄 Credential Loading

### Method 1: Using the Secure Credentials Utility

```bash
# Source the utility
source scripts/secure-credentials.sh

# Load and validate all credentials
init_secure_credentials

# Or load specific file
load_env_file /path/to/your/.env

# Validate specific credential
validate_env_var "GITEA_TOKEN" "Gitea API Token"
```

### Method 2: Manual Export

```bash
# Export individual credentials
export GITEA_TOKEN="your_token_here"
export MINIO_ACCESS_KEY="your_access_key"
export MINIO_SECRET_KEY="your_secret_key"

# Validate
source scripts/secure-credentials.sh
validate_required_credentials
```

### Method 3: Direct File Sourcing (Basic)

```bash
# Load environment file directly (less secure)
set -a  # Automatically export all variables
source .env
set +a  # Turn off automatic export
```

## 🏗️ Jenkins Integration

### Setup Jenkins Credentials Securely

1. **Set environment variables** in your shell:
   ```bash
   export GITEA_TOKEN="your_actual_token"
   export MINIO_ACCESS_KEY="your_access_key"
   export MINIO_SECRET_KEY="your_secret_key"
   ```

2. **Copy the secure script** content:
   ```bash
   cat secure-jenkins-credentials.groovy
   ```

3. **Run in Jenkins Script Console**:
   - Go to Jenkins → Manage Jenkins → Script Console
   - Paste the script content
   - Click "Run"

### Verify Jenkins Credentials

After setup, you should see these credentials in Jenkins:
- ✅ `gitea-token` (Secret text)
- ✅ `minio-creds` (Username with password)  
- ✅ `kubeconfig` (Secret file) - *manually uploaded*

## 🏗️ Terraform Integration

### Using the Secure Terraform Wrapper

```bash
# Initialize credentials
source scripts/secure-credentials.sh
init_secure_credentials

# Use the secure wrapper
./scripts/secure-terraform.sh init
./scripts/secure-terraform.sh plan
./scripts/secure-terraform.sh apply -auto-approve
./scripts/secure-terraform.sh destroy
```

### Manual Terraform with Environment Variables

```bash
# Set Terraform-specific variables
export TF_VAR_minio_access_key="$MINIO_ACCESS_KEY"
export TF_VAR_minio_secret_key="$MINIO_SECRET_KEY"
export TF_VAR_grafana_admin_password="$GRAFANA_ADMIN_PASSWORD"

# Run Terraform normally
cd infra/terraform
terraform init
terraform plan
terraform apply
```

## 🔒 Security Best Practices

### File Security

```bash
# Secure .env file permissions
chmod 600 .env

# Verify .env is not tracked by git
git ls-files --error-unmatch .env 2>/dev/null && echo "WARNING: .env is tracked!"

# Add to .gitignore if not present
echo ".env" >> .gitignore
```

### Environment Security

```bash
# Check environment security
source scripts/secure-credentials.sh
check_secure_environment

# Generate secure tokens
generate_secure_token 32  # 32-character token
```

### Access Control

- **Principle of Least Privilege**: Only grant access to credentials that are needed
- **Separate Environments**: Use different credentials for dev/staging/production
- **Regular Audits**: Review who has access to credentials regularly

### Network Security

- Use HTTPS/TLS for all credential transmission
- Avoid credentials in URLs or logs
- Use secure channels for credential sharing

## 🔄 Credential Rotation

### Automatic Rotation

```bash
# Source the utility
source scripts/secure-credentials.sh

# Rotate a credential (generates new random value)
rotate_credential "GITEA_TOKEN"

# Rotate with specific value
rotate_credential "MINIO_SECRET_KEY" "new_secret_value"
```

### Manual Rotation Process

1. **Generate new credential** in the source system (Gitea, MinIO, etc.)
2. **Update .env file** with new value
3. **Test the new credential**:
   ```bash
   source scripts/secure-credentials.sh
   validate_env_var "GITEA_TOKEN"
   ```
4. **Update Jenkins credentials**:
   - Export new values and run `secure-jenkins-credentials.groovy`
5. **Verify all services** are working with new credentials
6. **Revoke old credential** in the source system

### Rotation Schedule

| Credential Type | Recommended Rotation |
|----------------|---------------------|
| API Tokens | Every 90 days |
| Passwords | Every 60 days |
| Service Account Keys | Every 30 days |
| Development Credentials | Every 180 days |

## 💾 Backup and Recovery

### Create Encrypted Backup

```bash
source scripts/secure-credentials.sh

# Create encrypted backup
backup_credentials

# Specify custom backup directory
backup_credentials "/path/to/secure/backup/dir"
```

### Restore from Backup

```bash
# List available backups
ls -la backups/

# Restore encrypted backup
gpg --decrypt backups/credentials_backup_20250923_123456.env.gpg > .env

# Verify restored credentials
source scripts/secure-credentials.sh
validate_required_credentials
```

### Backup Best Practices

- **Encrypt all backups** using GPG or similar
- **Store backups separately** from main system
- **Test restore process** regularly
- **Document backup locations** securely
- **Set appropriate retention** periods

## 🔧 Troubleshooting

### Common Issues

#### 1. "Environment variable not set" Error

```bash
# Check if variable is set
echo "GITEA_TOKEN is: ${GITEA_TOKEN:-NOT_SET}"

# Load from .env file
source scripts/secure-credentials.sh
load_env_file .env
```

#### 2. Permission Denied on .env File

```bash
# Fix file permissions
chmod 600 .env
chown $(whoami) .env
```

#### 3. Git Tracking .env File

```bash
# Remove from git tracking
git rm --cached .env
echo ".env" >> .gitignore
git add .gitignore
git commit -m "Stop tracking .env file"
```

#### 4. Jenkins Can't Find Credentials

```bash
# Verify environment variables are set in Jenkins execution context
echo "Environment variables in Jenkins:"
env | grep -E "(GITEA|MINIO)" || echo "No credentials found"

# Re-run the credential setup script
# Copy and run secure-jenkins-credentials.groovy in Jenkins Script Console
```

### Debug Mode

```bash
# Enable debug logging
export DEBUG=true
source scripts/secure-credentials.sh
init_secure_credentials
```

### Validation Tools

```bash
# Validate specific credential
validate_env_var "GITEA_TOKEN" "Gitea API Token"

# Check all required credentials
validate_required_credentials

# Security environment check
check_secure_environment
```

## 📦 Migration from Old System

### Pre-Migration Checklist

- [ ] Backup existing Jenkins credentials
- [ ] Document current credential locations
- [ ] Identify all hardcoded credentials
- [ ] Plan rotation schedule for exposed credentials

### Migration Steps

#### Step 1: Create Environment File

```bash
# Copy template
cp .env.example .env

# Add your existing credentials from old system:
# - GITEA_TOKEN=9b407fc263328ce9f89b41721d80b48a306ece8d  (from old .groovy files)
# - MINIO_ACCESS_KEY=minioadmin  (from old .groovy files)
# - MINIO_SECRET_KEY=FiXKggTsc4gnR  (from old .groovy files)
```

#### Step 2: Remove Old Hardcoded Files

```bash
# Move old credential files to backup
mkdir -p backup/deprecated-credentials
mv setup-jenkins-credentials.groovy backup/deprecated-credentials/
mv simple-jenkins-credentials.groovy backup/deprecated-credentials/
mv jenkins-credentials.groovy backup/deprecated-credentials/

# Update references in documentation
```

#### Step 3: Update Jenkins

```bash
# Load new credentials
source scripts/secure-credentials.sh
init_secure_credentials

# Run new secure setup in Jenkins Script Console
cat secure-jenkins-credentials.groovy
```

#### Step 4: Test New System

```bash
# Validate all credentials
validate_required_credentials

# Test Jenkins pipeline
# Test Terraform operations
./scripts/secure-terraform.sh validate
```

#### Step 5: Rotate Exposed Credentials

Since the old credentials were hardcoded and potentially exposed:

```bash
# Rotate all credentials that were previously hardcoded
# 1. Generate new tokens in Gitea, MinIO, etc.
# 2. Update .env with new values
# 3. Run credential validation
validate_required_credentials

# 4. Update Jenkins with new credentials
# 5. Revoke old credentials in source systems
```

### Post-Migration Verification

- [ ] All pipelines work with new credential system
- [ ] No hardcoded credentials remain in codebase
- [ ] All team members have access to new credential management system
- [ ] Backup and rotation procedures are documented
- [ ] Old credentials have been revoked

## 📚 Additional Resources

### Scripts and Utilities

| Script | Purpose |
|--------|---------|
| `scripts/secure-credentials.sh` | Main credential management utility |
| `scripts/secure-terraform.sh` | Secure Terraform wrapper |
| `secure-jenkins-credentials.groovy` | Secure Jenkins credential setup |
| `.env.example` | Environment variable template |

### Security Tools

- **GPG**: For encrypting credential backups
- **OpenSSL**: For generating secure tokens
- **Git Secrets**: For preventing credential commits
- **Vault** (optional): For enterprise credential management

### Documentation

- [Jenkins Credentials Plugin Documentation](https://plugins.jenkins.io/credentials/)
- [Terraform Environment Variables](https://www.terraform.io/docs/commands/environment-variables.html)
- [MinIO Access Keys](https://docs.min.io/docs/minio-admin-complete-guide.html)

## 🆘 Support

If you need help with the secure credential management system:

1. **Check this documentation** for common solutions
2. **Run diagnostic tools**:
   ```bash
   source scripts/secure-credentials.sh
   check_secure_environment
   validate_required_credentials
   ```
3. **Enable debug mode** for detailed logging:
   ```bash
   export DEBUG=true
   ```
4. **Review security warnings** and fix them before proceeding

## 📝 Changelog

### Version 2.0 (Current) - Secure Credential Management
- ✅ Environment variable-based credential system
- ✅ Secure loading and validation utilities
- ✅ Encrypted backup and rotation capabilities
- ✅ Jenkins integration with environment variables
- ✅ Terraform wrapper with security checks
- ✅ Comprehensive documentation and migration guide

### Version 1.0 (Deprecated) - Hardcoded Credentials
- ❌ Hardcoded credentials in Groovy scripts
- ❌ Security vulnerabilities
- ❌ No credential rotation capabilities
- ❌ Limited documentation