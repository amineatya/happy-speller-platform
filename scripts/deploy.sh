#!/bin/bash

# Happy Speller Deployment Script
# This script handles the complete deployment of the Happy Speller application

set -e

# Configuration
NAMESPACE="demo"
APP_NAME="happy-speller"
REGISTRY="registry.local:5000"
HELM_CHART_PATH="./helm/app"

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
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again."
        exit 1
    fi
    
    log_info "All prerequisites are installed."
}

# Build Docker image
build_image() {
    local image_tag="${REGISTRY}/${APP_NAME}:${BUILD_NUMBER:-latest}"
    
    log_info "Building Docker image: ${image_tag}"
    
    cd app
    docker build -t "${image_tag}" .
    cd ..
    
    log_info "Docker image built successfully."
}

# Deploy to Kubernetes using Helm
deploy_to_k8s() {
    local image_tag="${REGISTRY}/${APP_NAME}:${BUILD_NUMBER:-latest}"
    
    log_info "Deploying to Kubernetes namespace: ${NAMESPACE}"
    
    # Create namespace if it doesn't exist
    kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy with Helm
    helm upgrade --install "${APP_NAME}" "${HELM_CHART_PATH}" \
        --namespace "${NAMESPACE}" \
        --set image.repository="${REGISTRY}/${APP_NAME}" \
        --set image.tag="${BUILD_NUMBER:-latest}" \
        --set replicaCount=2 \
        --wait
    
    log_info "Application deployed successfully."
}

# Run smoke tests
run_smoke_tests() {
    log_info "Running smoke tests..."
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/"${APP_NAME}" -n "${NAMESPACE}"
    
    # Test health endpoint
    local pod_name=$(kubectl get pods -n "${NAMESPACE}" -l app="${APP_NAME}" -o jsonpath='{.items[0].metadata.name}')
    
    if kubectl exec -n "${NAMESPACE}" "${pod_name}" -- curl -s http://localhost:8080/healthz | grep -q '"status":"ok"'; then
        log_info "Health check passed."
    else
        log_error "Health check failed."
        exit 1
    fi
    
    # Test version endpoint
    if kubectl exec -n "${NAMESPACE}" "${pod_name}" -- curl -s http://localhost:8080/api/version | grep -q '"name":"Happy Speller"'; then
        log_info "Version endpoint test passed."
    else
        log_error "Version endpoint test failed."
        exit 1
    fi
    
    log_info "All smoke tests passed."
}

# Show deployment status
show_status() {
    log_info "Deployment status:"
    echo ""
    
    # Show pods
    kubectl get pods -n "${NAMESPACE}" -l app="${APP_NAME}"
    echo ""
    
    # Show services
    kubectl get services -n "${NAMESPACE}" -l app="${APP_NAME}"
    echo ""
    
    # Show ingress if exists
    kubectl get ingress -n "${NAMESPACE}" -l app="${APP_NAME}" 2>/dev/null || true
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    # Add any cleanup logic here
}

# Main deployment function
main() {
    log_info "Starting Happy Speller deployment..."
    
    # Set up trap for cleanup on exit
    trap cleanup EXIT
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-only)
                BUILD_ONLY=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --build-only    Only build the Docker image, don't deploy"
                echo "  --skip-tests    Skip smoke tests"
                echo "  --help          Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Run deployment steps
    check_prerequisites
    build_image
    
    if [ "${BUILD_ONLY:-false}" = "true" ]; then
        log_info "Build-only mode: skipping deployment."
        exit 0
    fi
    
    deploy_to_k8s
    
    if [ "${SKIP_TESTS:-false}" = "false" ]; then
        run_smoke_tests
    fi
    
    show_status
    
    log_info "Deployment completed successfully!"
}

# Run main function
main "$@"
