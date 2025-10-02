# Terraform MinIO Backend Setup

This directory contains Terraform configuration that uses MinIO as an S3-compatible backend for storing Terraform state files.

## Prerequisites

1. **MinIO Server**: Ensure MinIO is running and accessible
2. **MinIO Client (optional)**: Install `mc` for bucket management
3. **Terraform**: Version >= 1.0

## Quick Start

### 1. Verify MinIO Server Access

Ensure your MinIO server at `http://192.168.50.177:9001/` is running and accessible.

```bash
# Test connectivity
curl -s http://192.168.50.177:9000/minio/health/live
```

### 2. Initialize Terraform with MinIO Backend

Run the initialization script:

```bash
./init-minio-backend.sh
```

Or manually:

```bash
# Update backend.conf with your MinIO settings
# Then initialize Terraform
terraform init -backend-config=backend.conf -reconfigure
```

### 3. Configure Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your settings
# Note: For security, use environment variables for sensitive values
```

### 4. Deploy Infrastructure

```bash
terraform plan
terraform apply
```

## Configuration Files

### `backend.conf`
Contains the S3 backend configuration for MinIO:
- `bucket`: S3 bucket name for state storage
- `endpoint`: MinIO server endpoint
- `access_key` & `secret_key`: MinIO credentials
- Various S3-compatibility flags

### `terraform.tfvars.example`
Example variable values. Copy to `terraform.tfvars` and customize.

### `init-minio-backend.sh`
Automated setup script that:
- Checks MinIO connectivity
- Creates the state bucket if needed
- Updates backend configuration
- Initializes Terraform

## Environment Variables

For security, use environment variables instead of hardcoding credentials:

```bash
# Backend credentials (alternative to backend.conf)
export AWS_ACCESS_KEY_ID="your-minio-access-key"
export AWS_SECRET_ACCESS_KEY="your-minio-secret-key"

# Terraform variables
export TF_VAR_minio_access_key="your-minio-access-key"
export TF_VAR_minio_secret_key="your-minio-secret-key"
export TF_VAR_grafana_admin_password="your-grafana-password"
```

## Script Options

The `init-minio-backend.sh` script accepts the following options:

```bash
./init-minio-backend.sh --help

Options:
  --endpoint     MinIO endpoint URL (default: http://localhost:9000)
  --access-key   MinIO access key (default: minioadmin)
  --secret-key   MinIO secret key (default: minioadmin)
  --bucket       S3 bucket for state (default: terraform-state)
  --key          S3 key for state file (default: happy-speller/terraform.tfstate)
```

## Example Usage

### Custom MinIO Endpoint

```bash
./init-minio-backend.sh --endpoint https://minio.example.com:9000
```

### Custom Credentials

```bash
./init-minio-backend.sh \
  --access-key myaccesskey \
  --secret-key mysecretkey \
  --bucket my-terraform-state
```

### Using Environment Variables

```bash
export MINIO_ENDPOINT="https://minio.example.com:9000"
export MINIO_ACCESS_KEY="myaccesskey"
export MINIO_SECRET_KEY="mysecretkey"
export STATE_BUCKET="my-terraform-state"

./init-minio-backend.sh
```

## Troubleshooting

### MinIO Connection Issues

1. Verify MinIO is running: `curl http://192.168.50.177:9000/minio/health/live`
2. Check firewall/network connectivity
3. Verify credentials in `backend.conf`

### State Migration

To migrate from local state to MinIO:

```bash
# Backup existing state
cp terraform.tfstate terraform.tfstate.backup

# Initialize with MinIO backend
./init-minio-backend.sh

# Terraform will prompt to migrate state
```

### State Lock Issues

If you encounter state lock issues:

```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

## Security Best Practices

1. **Never commit sensitive values** to version control
2. **Use environment variables** for credentials
3. **Rotate access keys** regularly
4. **Enable bucket versioning** in MinIO for state history
5. **Restrict bucket access** to only necessary users/services

## MinIO Console

Access the MinIO web console at: http://192.168.50.177:9001
- Default credentials: `minioadmin` / `minioadmin`
- Use to manage buckets, view state files, and configure policies

## State File Location

Once configured, your Terraform state will be stored at:
```
MinIO Endpoint: http://192.168.50.177:9000
Bucket: terraform-state
Key: happy-speller/terraform.tfstate
```

You can view and manage the state file through the MinIO console or using the MinIO client (`mc`).