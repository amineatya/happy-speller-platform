#!/bin/bash

# Terraform MinIO Backend Initialization Script
# This script helps initialize Terraform with MinIO as the S3-compatible backend

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://192.168.50.177:9000}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-minioadmin}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-minioadmin}"
STATE_BUCKET="${STATE_BUCKET:-terraform-state}"
STATE_KEY="${STATE_KEY:-happy-speller/terraform.tfstate}"

echo -e "${BLUE}=== Terraform MinIO Backend Initialization ===${NC}"
echo

# Function to check if MinIO is running
check_minio() {
    echo -e "${YELLOW}Checking MinIO connectivity...${NC}"
    if curl -s --connect-timeout 5 "${MINIO_ENDPOINT}/minio/health/live" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ MinIO is running at ${MINIO_ENDPOINT}${NC}"
        return 0
    else
        echo -e "${RED}✗ MinIO is not accessible at ${MINIO_ENDPOINT}${NC}"
        return 1
    fi
}

# Function to create bucket if it doesn't exist
create_bucket() {
    echo -e "${YELLOW}Creating bucket '${STATE_BUCKET}' if it doesn't exist...${NC}"
    
    # Check if mc (MinIO client) is available
    if command -v mc > /dev/null 2>&1; then
        # Configure mc client
        mc alias set myminio "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" > /dev/null 2>&1 || true
        
        # Create bucket if it doesn't exist
        if ! mc ls myminio/"${STATE_BUCKET}" > /dev/null 2>&1; then
            mc mb myminio/"${STATE_BUCKET}"
            echo -e "${GREEN}✓ Created bucket '${STATE_BUCKET}'${NC}"
        else
            echo -e "${GREEN}✓ Bucket '${STATE_BUCKET}' already exists${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ MinIO client 'mc' not found. Please create bucket '${STATE_BUCKET}' manually${NC}"
        echo -e "${YELLOW}  You can install mc with: brew install minio/stable/mc${NC}"
    fi
}

# Function to update backend configuration
update_backend_config() {
    echo -e "${YELLOW}Updating backend.conf...${NC}"
    
    cat > backend.conf << EOF
bucket                      = "${STATE_BUCKET}"
key                         = "${STATE_KEY}"
region                      = "us-east-1"
endpoint                    = "${MINIO_ENDPOINT}"
access_key                  = "${MINIO_ACCESS_KEY}"
secret_key                  = "${MINIO_SECRET_KEY}"
force_path_style           = true
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
EOF
    
    echo -e "${GREEN}✓ Updated backend.conf${NC}"
}

# Function to initialize Terraform
init_terraform() {
    echo -e "${YELLOW}Initializing Terraform with MinIO backend...${NC}"
    
    # Remove existing .terraform directory if it exists
    if [ -d ".terraform" ]; then
        echo -e "${YELLOW}Removing existing .terraform directory...${NC}"
        rm -rf .terraform
    fi
    
    # Initialize with backend configuration
    if terraform init -backend-config=backend.conf -reconfigure; then
        echo -e "${GREEN}✓ Terraform initialized successfully with MinIO backend${NC}"
    else
        echo -e "${RED}✗ Failed to initialize Terraform${NC}"
        exit 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}Configuration:${NC}"
    echo -e "  MinIO Endpoint: ${MINIO_ENDPOINT}"
    echo -e "  State Bucket: ${STATE_BUCKET}"
    echo -e "  State Key: ${STATE_KEY}"
    echo
    
    # Check if MinIO is running
    if ! check_minio; then
        echo -e "${RED}Please ensure MinIO is running at ${MINIO_ENDPOINT} before proceeding.${NC}"
        echo -e "${YELLOW}Check that your MinIO server at 192.168.50.177 is accessible and running.${NC}"
        exit 1
    fi
    
    # Create bucket
    create_bucket
    
    # Update backend configuration
    update_backend_config
    
    # Initialize Terraform
    init_terraform
    
    echo
    echo -e "${GREEN}=== Initialization Complete ===${NC}"
    echo -e "${GREEN}Your Terraform state will now be stored in MinIO at:${NC}"
    echo -e "${GREEN}  ${MINIO_ENDPOINT}/${STATE_BUCKET}/${STATE_KEY}${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Copy terraform.tfvars.example to terraform.tfvars"
    echo -e "  2. Update terraform.tfvars with your configuration"
    echo -e "  3. Run 'terraform plan' to review changes"
    echo -e "  4. Run 'terraform apply' to deploy"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --endpoint)
            MINIO_ENDPOINT="$2"
            shift 2
            ;;
        --access-key)
            MINIO_ACCESS_KEY="$2"
            shift 2
            ;;
        --secret-key)
            MINIO_SECRET_KEY="$2"
            shift 2
            ;;
        --bucket)
            STATE_BUCKET="$2"
            shift 2
            ;;
        --key)
            STATE_KEY="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --endpoint     MinIO endpoint URL (default: http://192.168.50.177:9000)"
            echo "  --access-key   MinIO access key (default: minioadmin)"
            echo "  --secret-key   MinIO secret key (default: minioadmin)"
            echo "  --bucket       S3 bucket for state (default: terraform-state)"
            echo "  --key          S3 key for state file (default: happy-speller/terraform.tfstate)"
            echo "  --help         Show this help message"
            echo
            echo "Environment variables:"
            echo "  MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY"
            echo "  STATE_BUCKET, STATE_KEY"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main