#!/bin/bash

# =============================================================================
# Secure Terraform Wrapper Script
# =============================================================================
# This script provides a secure way to run Terraform commands with credentials
# loaded from environment variables, without exposing them in command history
# or configuration files.
#
# Usage:
#   ./scripts/secure-terraform.sh init
#   ./scripts/secure-terraform.sh plan
#   ./scripts/secure-terraform.sh apply
#   ./scripts/secure-terraform.sh destroy
# =============================================================================

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/infra/terraform"

# Source the secure credentials utility
source "$SCRIPT_DIR/secure-credentials.sh"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() {
    echo -e "${BLUE}[TERRAFORM]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[TERRAFORM]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[TERRAFORM]${NC} $*"
}

log_error() {
    echo -e "${RED}[TERRAFORM]${NC} $*" >&2
}

# Function to validate Terraform-specific credentials
validate_terraform_credentials() {
    log_info "Validating Terraform credentials..."
    
    local validation_failed=false
    
    # Required Terraform variables (using TF_VAR_ prefix)
    local tf_vars=(
        "TF_VAR_minio_access_key:MinIO Access Key for Terraform"
        "TF_VAR_minio_secret_key:MinIO Secret Key for Terraform"
        "TF_VAR_grafana_admin_password:Grafana Admin Password for Terraform"
    )
    
    for var_info in "${tf_vars[@]}"; do
        IFS=':' read -r var_name description <<< "$var_info"
        if ! validate_env_var "$var_name" "$description"; then
            validation_failed=true
        fi
    done
    
    # Also check if regular env vars exist and copy them to TF_VAR_ if needed
    if [[ -n "${MINIO_ACCESS_KEY:-}" && -z "${TF_VAR_minio_access_key:-}" ]]; then
        export TF_VAR_minio_access_key="$MINIO_ACCESS_KEY"
        log_info "Copied MINIO_ACCESS_KEY to TF_VAR_minio_access_key"
    fi
    
    if [[ -n "${MINIO_SECRET_KEY:-}" && -z "${TF_VAR_minio_secret_key:-}" ]]; then
        export TF_VAR_minio_secret_key="$MINIO_SECRET_KEY"
        log_info "Copied MINIO_SECRET_KEY to TF_VAR_minio_secret_key"
    fi
    
    if [[ -n "${GRAFANA_ADMIN_PASSWORD:-}" && -z "${TF_VAR_grafana_admin_password:-}" ]]; then
        export TF_VAR_grafana_admin_password="$GRAFANA_ADMIN_PASSWORD"
        log_info "Copied GRAFANA_ADMIN_PASSWORD to TF_VAR_grafana_admin_password"
    fi
    
    if [[ "$validation_failed" == "true" ]]; then
        log_error "Terraform credential validation failed!"
        log_error "Please set the required TF_VAR_ environment variables."
        return 1
    fi
    
    log_success "Terraform credentials validated successfully!"
    return 0
}

# Function to run Terraform with security checks
run_terraform() {
    local terraform_cmd="$1"
    shift  # Remove first argument, rest are terraform arguments
    
    log_info "Running secure Terraform: $terraform_cmd"
    
    # Change to Terraform directory
    cd "$TERRAFORM_DIR"
    
    # Validate credentials before running Terraform
    if ! validate_terraform_credentials; then
        log_error "Credential validation failed. Aborting Terraform execution."
        return 1
    fi
    
    # Check if terraform.tfvars exists and warn if it contains sensitive data
    if [[ -f "terraform.tfvars" ]]; then
        log_warning "Found terraform.tfvars file. Checking for sensitive data..."
        
        if grep -qE "(access_key|secret_key|password).*=" terraform.tfvars; then
            log_error "terraform.tfvars contains sensitive credentials!"
            log_error "This is a security risk. Please remove sensitive data and use environment variables."
            log_error "See terraform.tfvars.example for secure configuration."
            return 1
        else
            log_info "terraform.tfvars appears safe (no obvious sensitive data detected)"
        fi
    fi
    
    # Set Terraform-specific environment variables for enhanced security
    export TF_INPUT=false  # Disable interactive prompts
    export TF_IN_AUTOMATION=true  # Indicate we're running in automation
    
    log_info "Executing: terraform $terraform_cmd $*"
    
    # Execute Terraform command
    case "$terraform_cmd" in
        "init")
            terraform init -input=false "$@"
            ;;
        "plan")
            terraform plan -input=false -detailed-exitcode "$@"
            ;;
        "apply")
            if [[ "$*" != *"-auto-approve"* ]]; then
                log_warning "Running apply without -auto-approve. You will be prompted for confirmation."
            fi
            terraform apply -input=false "$@"
            ;;
        "destroy")
            if [[ "$*" != *"-auto-approve"* ]]; then
                log_warning "Running destroy without -auto-approve. You will be prompted for confirmation."
            fi
            terraform destroy -input=false "$@"
            ;;
        "validate")
            terraform validate "$@"
            ;;
        "fmt")
            terraform fmt -check=true -diff=true "$@"
            ;;
        "show")
            terraform show "$@"
            ;;
        "output")
            terraform output "$@"
            ;;
        "state")
            terraform state "$@"
            ;;
        *)
            log_warning "Running custom terraform command: $terraform_cmd"
            terraform "$terraform_cmd" "$@"
            ;;
    esac
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Terraform $terraform_cmd completed successfully!"
    else
        log_error "Terraform $terraform_cmd failed with exit code: $exit_code"
    fi
    
    return $exit_code
}

# Function to setup Terraform backend configuration securely
setup_terraform_backend() {
    log_info "Setting up Terraform backend configuration..."
    
    # Check if we need to configure a remote backend
    if [[ -n "${TF_BACKEND_CONFIG:-}" ]]; then
        log_info "Configuring Terraform backend: $TF_BACKEND_CONFIG"
        # Add backend configuration logic here if needed
    fi
    
    # Ensure .terraform directory has proper permissions
    if [[ -d "$TERRAFORM_DIR/.terraform" ]]; then
        chmod -R 700 "$TERRAFORM_DIR/.terraform"
        log_info "Secured .terraform directory permissions"
    fi
}

# Function to clean up sensitive environment variables after execution
cleanup_sensitive_vars() {
    log_info "Cleaning up sensitive environment variables..."
    
    # List of sensitive variables to unset
    local sensitive_vars=(
        "TF_VAR_minio_access_key"
        "TF_VAR_minio_secret_key" 
        "TF_VAR_grafana_admin_password"
    )
    
    for var in "${sensitive_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            unset "$var"
            log_debug "Cleaned up: $var"
        fi
    done
    
    log_success "Sensitive variables cleaned up"
}

# Print usage information
print_usage() {
    cat << EOF
🔐 Secure Terraform Wrapper

This script provides secure Terraform execution with credential management.

Usage:
    $0 <terraform_command> [terraform_arguments]

Common Commands:
    $0 init                     Initialize Terraform
    $0 plan                     Create execution plan
    $0 apply                    Apply changes
    $0 apply -auto-approve      Apply without confirmation
    $0 destroy                  Destroy infrastructure
    $0 validate                 Validate configuration
    $0 fmt                      Format configuration files
    $0 show                     Show current state
    $0 output                   Show output values

Prerequisites:
    - Environment variables must be set (see .env.example)
    - Or run: source scripts/secure-credentials.sh && init_secure_credentials

Environment Variables Required:
    TF_VAR_minio_access_key     MinIO access key
    TF_VAR_minio_secret_key     MinIO secret key  
    TF_VAR_grafana_admin_password Grafana admin password

Examples:
    # Load credentials and run Terraform
    source scripts/secure-credentials.sh
    init_secure_credentials
    $0 init
    $0 plan
    $0 apply -auto-approve

Security Features:
    ✓ Credentials loaded from environment variables only
    ✓ No sensitive data in command history
    ✓ Automatic credential validation
    ✓ Detection of sensitive data in .tfvars files
    ✓ Secure file permissions
    ✓ Automatic cleanup of sensitive variables

EOF
}

# Main execution
main() {
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi
    
    local terraform_command="$1"
    shift
    
    # Handle help/usage requests
    if [[ "$terraform_command" == "-h" || "$terraform_command" == "--help" || "$terraform_command" == "help" ]]; then
        print_usage
        exit 0
    fi
    
    log_info "🔐 Starting secure Terraform execution..."
    
    # Initialize secure credential management (but don't fail if credentials aren't set yet)
    VALIDATE_CREDENTIALS=false init_secure_credentials || true
    
    # Setup backend configuration
    setup_terraform_backend
    
    # Run Terraform command
    if run_terraform "$terraform_command" "$@"; then
        log_success "🎉 Terraform operation completed successfully!"
    else
        log_error "❌ Terraform operation failed!"
        cleanup_sensitive_vars
        exit 1
    fi
    
    # Clean up sensitive variables
    cleanup_sensitive_vars
    
    log_success "✅ Secure Terraform execution completed!"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi