#!/bin/bash

# Infrastructure Setup Script for Happy Speller
# This script sets up the infrastructure using Terraform and Ansible

set -e

# Configuration
TERRAFORM_DIR="./infra/terraform"
ANSIBLE_DIR="./infra/ansible"
NAMESPACE="demo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v ansible-playbook &> /dev/null; then
        missing_tools+=("ansible")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again."
        exit 1
    fi
    
    log_info "All prerequisites are installed."
}

# Setup Terraform
setup_terraform() {
    log_info "Setting up infrastructure with Terraform..."
    
    cd "${TERRAFORM_DIR}"
    
    # Initialize Terraform
    terraform init
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        log_warn "terraform.tfvars not found. Please create it from terraform.tfvars.example"
        log_warn "You can also set environment variables:"
        log_warn "  export TF_VAR_minio_access_key='your-key'"
        log_warn "  export TF_VAR_minio_secret_key='your-secret'"
        log_warn "  export TF_VAR_grafana_admin_password='your-password'"
    fi
    
    # Plan the deployment
    terraform plan -out=tfplan
    
    # Apply the plan
    terraform apply tfplan
    
    # Show outputs
    terraform output
    
    cd - > /dev/null
    
    log_info "Terraform setup completed."
}

# Setup Ansible
setup_ansible() {
    log_info "Setting up configuration with Ansible..."
    
    cd "${ANSIBLE_DIR}"
    
    # Install Ansible collections
    ansible-galaxy collection install -r requirements.yaml
    
    # Check if required environment variables are set
    local required_vars=("JENKINS_TOKEN" "GITEA_TOKEN" "MINIO_ACCESS_KEY" "MINIO_SECRET_KEY")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("${var}")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_warn "Missing environment variables: ${missing_vars[*]}"
        log_warn "Please set these variables and try again."
        log_warn "Example:"
        log_warn "  export JENKINS_TOKEN='your-jenkins-token'"
        log_warn "  export GITEA_TOKEN='your-gitea-token'"
        log_warn "  export MINIO_ACCESS_KEY='your-minio-key'"
        log_warn "  export MINIO_SECRET_KEY='your-minio-secret'"
        log_warn "  export KUBECONFIG='path-to-your-kubeconfig'"
    fi
    
    # Run Jenkins setup
    if [ -n "${JENKINS_TOKEN}" ]; then
        log_info "Configuring Jenkins..."
        ansible-playbook jenkins-setup.yaml
    else
        log_warn "Skipping Jenkins setup (JENKINS_TOKEN not set)"
    fi
    
    # Run Kubernetes setup
    if [ -n "${KUBECONFIG}" ]; then
        log_info "Configuring Kubernetes..."
        ansible-playbook k8s-setup.yaml
    else
        log_warn "Skipping Kubernetes setup (KUBECONFIG not set)"
    fi
    
    cd - > /dev/null
    
    log_info "Ansible setup completed."
}

# Verify setup
verify_setup() {
    log_info "Verifying setup..."
    
    # Check if namespace exists
    if kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        log_info "Namespace '${NAMESPACE}' exists."
    else
        log_warn "Namespace '${NAMESPACE}' not found."
    fi
    
    # Check if Jenkins is accessible
    if curl -s http://192.168.50.247:8080/login &> /dev/null; then
        log_info "Jenkins is accessible."
    else
        log_warn "Jenkins is not accessible."
    fi
    
    # Check if Gitea is accessible
    if curl -s http://192.168.50.130:3000 &> /dev/null; then
        log_info "Gitea is accessible."
    else
        log_warn "Gitea is not accessible."
    fi
    
    # Check if MinIO is accessible
    if curl -s http://192.168.68.58:9000 &> /dev/null; then
        log_info "MinIO is accessible."
    else
        log_warn "MinIO is not accessible."
    fi
    
    log_info "Verification completed."
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --terraform-only    Only run Terraform setup"
    echo "  --ansible-only      Only run Ansible setup"
    echo "  --skip-verify       Skip verification step"
    echo "  --help              Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  JENKINS_TOKEN       Jenkins API token"
    echo "  GITEA_TOKEN         Gitea API token"
    echo "  MINIO_ACCESS_KEY    MinIO access key"
    echo "  MINIO_SECRET_KEY    MinIO secret key"
    echo "  KUBECONFIG          Path to Kubernetes config file"
    echo ""
    echo "Example:"
    echo "  export JENKINS_TOKEN='your-token'"
    echo "  export GITEA_TOKEN='your-token'"
    echo "  export MINIO_ACCESS_KEY='your-key'"
    echo "  export MINIO_SECRET_KEY='your-secret'"
    echo "  export KUBECONFIG='~/.kube/config'"
    echo "  $0"
}

# Main function
main() {
    log_info "Starting infrastructure setup for Happy Speller..."
    
    # Parse command line arguments
    TERRAFORM_ONLY=false
    ANSIBLE_ONLY=false
    SKIP_VERIFY=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --terraform-only)
                TERRAFORM_ONLY=true
                shift
                ;;
            --ansible-only)
                ANSIBLE_ONLY=true
                shift
                ;;
            --skip-verify)
                SKIP_VERIFY=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Run setup steps
    check_prerequisites
    
    if [ "${ANSIBLE_ONLY}" = "false" ]; then
        setup_terraform
    fi
    
    if [ "${TERRAFORM_ONLY}" = "false" ]; then
        setup_ansible
    fi
    
    if [ "${SKIP_VERIFY}" = "false" ]; then
        verify_setup
    fi
    
    log_info "Infrastructure setup completed!"
}

# Run main function
main "$@"
