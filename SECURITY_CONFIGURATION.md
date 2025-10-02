# Security Configuration Guide

## 🔒 Credential Management

This repository contains template files for secure credential management. **Never commit files with real credentials to version control.**

### Files with Sensitive Data (DO NOT COMMIT)

The following files contain real credentials and are excluded from version control:

- `infra/terraform/backend.conf` - Terraform backend configuration with MinIO credentials
- `scripts/webhook-server.py` - Webhook server with Gitea token
- `upload-to-minio.sh` - MinIO upload script with credentials

### Template Files (Safe to Commit)

Use these template files as examples:

- `infra/terraform/backend.conf.example` - Terraform backend template
- `scripts/webhook-server.py.example` - Webhook server template  
- `upload-to-minio.sh.example` - MinIO upload template

## 🛠️ Setup Instructions

### 1. Terraform Backend Configuration

```bash
# Copy the template
cp infra/terraform/backend.conf.example infra/terraform/backend.conf

# Edit with your actual values
nano infra/terraform/backend.conf
```

Required values:
- `endpoint` - Your MinIO endpoint URL
- `access_key` - Your MinIO access key
- `secret_key` - Your MinIO secret key

### 2. Webhook Server Configuration

```bash
# Copy the template
cp scripts/webhook-server.py.example scripts/webhook-server.py

# Edit with your actual values
nano scripts/webhook-server.py
```

Required values:
- `WEBHOOK_SECRET` - Your Gitea webhook secret (or set via environment variable)
- `PROJECT_DIR` - Path to your project directory

### 3. MinIO Upload Script

```bash
# Copy the template
cp upload-to-minio.sh.example upload-to-minio.sh

# Edit with your actual values
nano upload-to-minio.sh
```

Required values:
- `MINIO_ENDPOINT` - Your MinIO endpoint URL
- `MINIO_ACCESS_KEY` - Your MinIO access key
- `MINIO_SECRET_KEY` - Your MinIO secret key

## 🔐 Environment Variables (Recommended)

For better security, use environment variables instead of hardcoded values:

```bash
# Set environment variables
export MINIO_ACCESS_KEY="your-access-key"
export MINIO_SECRET_KEY="your-secret-key"
export WEBHOOK_SECRET="your-webhook-secret"

# Run scripts
python3 scripts/webhook-server.py
./upload-to-minio.sh
```

## ✅ Verification

Before committing, verify no sensitive data is exposed:

```bash
# Check for exposed credentials
grep -r "password\|secret\|key" --include="*.py" --include="*.sh" --include="*.conf" . | grep -v example
grep -r "minioadmin\|FiXKggTsc4gnR" --include="*.py" --include="*.sh" --include="*.conf" . | grep -v example
```

## 🚨 Security Checklist

- [ ] All template files created with placeholder values
- [ ] Real credential files added to `.gitignore`
- [ ] No hardcoded passwords in committed files
- [ ] Environment variables used where possible
- [ ] Documentation updated with setup instructions
