#!/bin/bash

# Happy Speller Deployment Script
# This script handles the complete deployment of the Happy Speller application

set -e

# Configuration
NAMESPACE="${NAMESPACE:-demo}"
APP_NAME="${APP_NAME:-happy-speller}"
REGISTRY="${REGISTRY:-registry.local:5000}"
HELM_CHART_PATH="${HELM_CHART_PATH:-./helm/app}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M%S)}"
SHORT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'local')"

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
    local image_tag="${REGISTRY}/${APP_NAME}:${BUILD_NUMBER}-${SHORT_COMMIT}"
    local latest_tag="${REGISTRY}/${APP_NAME}:latest"
    
    log_info "Building Docker image: ${image_tag}"
    log_info "Also tagging as: ${latest_tag}"
    
    if [ ! -f "app/Dockerfile" ]; then
        log_error "Dockerfile not found in app directory"
        exit 1
    fi
    
    cd app
    
    # Build with build args for better caching
    docker build \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VERSION="${BUILD_NUMBER}-${SHORT_COMMIT}" \
        -t "${image_tag}" \
        -t "${latest_tag}" \
        .
    
    cd ..
    
    # Verify image was built
    if docker image inspect "${image_tag}" >/dev/null 2>&1; then
        log_info "Docker image built successfully: ${image_tag}"
        echo "Image ID: $(docker images --no-trunc --quiet ${image_tag})"
        echo "Image Size: $(docker image inspect ${image_tag} --format='{{.Size}}' | numfmt --to=iec-i --suffix=B)"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
}

# Deploy to Kubernetes using Helm
deploy_to_k8s() {
    local image_tag="${REGISTRY}/${APP_NAME}:${BUILD_NUMBER}-${SHORT_COMMIT}"
    
    log_info "Deploying to Kubernetes namespace: ${NAMESPACE}"
    log_info "Using image: ${image_tag}"
    
    # Create namespace if it doesn't exist
    log_info "Ensuring namespace ${NAMESPACE} exists..."
    kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    
    # Check if Helm chart exists
    if [ ! -f "${HELM_CHART_PATH}/Chart.yaml" ]; then
        log_error "Helm chart not found at ${HELM_CHART_PATH}"
        exit 1
    fi
    
    # Store current revision for rollback
    if helm list -n "${NAMESPACE}" -o json | jq -r '.[] | select(.name=="'${APP_NAME}'") | .revision' | grep -q "[0-9]"; then
        PREVIOUS_REVISION=$(helm list -n "${NAMESPACE}" -o json | jq -r '.[] | select(.name=="'${APP_NAME}'") | .revision')
        log_info "Current revision: ${PREVIOUS_REVISION}"
        echo "PREVIOUS_REVISION=${PREVIOUS_REVISION}" > /tmp/deployment.env
    fi
    
    # Validate Helm chart
    log_info "Validating Helm chart..."
    helm template "${APP_NAME}" "${HELM_CHART_PATH}" \
        --namespace "${NAMESPACE}" \
        --set image.repository="${REGISTRY}/${APP_NAME}" \
        --set image.tag="${BUILD_NUMBER}-${SHORT_COMMIT}" \
        --set replicaCount=2 > /dev/null
    
    if [ $? -eq 0 ]; then
        log_info "Helm chart validation passed"
    else
        log_error "Helm chart validation failed"
        exit 1
    fi
    
    # Deploy with Helm
    log_info "Starting Helm deployment..."
    helm upgrade --install "${APP_NAME}" "${HELM_CHART_PATH}" \
        --namespace "${NAMESPACE}" \
        --set image.repository="${REGISTRY}/${APP_NAME}" \
        --set image.tag="${BUILD_NUMBER}-${SHORT_COMMIT}" \
        --set replicaCount=2 \
        --timeout=600s \
        --wait \
        --atomic
    
    if [ $? -eq 0 ]; then
        log_info "Helm deployment successful"
        NEW_REVISION=$(helm list -n "${NAMESPACE}" -o json | jq -r '.[] | select(.name=="'${APP_NAME}'") | .revision')
        log_info "New revision: ${NEW_REVISION}"
    else
        log_error "Helm deployment failed"
        exit 1
    fi
    
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

# Rollback function
rollback() {
    log_warn "Initiating rollback..."
    
    if [ -f "/tmp/deployment.env" ]; then
        source /tmp/deployment.env
        if [ -n "${PREVIOUS_REVISION}" ]; then
            log_info "Rolling back to revision ${PREVIOUS_REVISION}"
            helm rollback "${APP_NAME}" "${PREVIOUS_REVISION}" -n "${NAMESPACE}"
            
            # Wait for rollback to complete
            kubectl wait --for=condition=available --timeout=300s deployment/"${APP_NAME}" -n "${NAMESPACE}" || true
            
            log_info "Rollback completed to revision ${PREVIOUS_REVISION}"
        else
            log_warn "No previous revision found for rollback"
        fi
    else
        log_warn "No deployment state found for rollback"
    fi
}

# Monitor deployment function
monitor_deployment() {
    log_info "Monitoring deployment progress..."
    
    # Check deployment status
    local max_wait=300
    local wait_time=0
    local check_interval=10
    
    while [ $wait_time -lt $max_wait ]; do
        local ready_replicas=$(kubectl get deployment "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get deployment "${APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        log_info "Deployment status: ${ready_replicas}/${desired_replicas} replicas ready"
        
        if [ "${ready_replicas}" = "${desired_replicas}" ] && [ "${ready_replicas}" != "0" ]; then
            log_info "Deployment is ready!"
            return 0
        fi
        
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    log_error "Deployment did not become ready within ${max_wait} seconds"
    return 1
}

# Check application health
check_health() {
    log_info "Checking application health..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Health check attempt ${attempt}/${max_attempts}"
        
        # Get a pod name
        local pod_name=$(kubectl get pods -n "${NAMESPACE}" -l app="${APP_NAME}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        
        if [ -z "${pod_name}" ]; then
            log_warn "No pods found, waiting..."
            sleep 10
            attempt=$((attempt + 1))
            continue
        fi
        
        # Check if pod is ready
        local pod_ready=$(kubectl get pod "${pod_name}" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        
        if [ "${pod_ready}" != "True" ]; then
            log_info "Pod ${pod_name} not ready yet, waiting..."
            sleep 10
            attempt=$((attempt + 1))
            continue
        fi
        
        # Test health endpoint
        if kubectl exec -n "${NAMESPACE}" "${pod_name}" -- curl -f -s http://localhost:8080/healthz >/dev/null 2>&1; then
            log_info "Health check passed for pod ${pod_name}"
            return 0
        else
            log_warn "Health check failed for pod ${pod_name}"
        fi
        
        sleep 10
        attempt=$((attempt + 1))
    done
    
    log_error "Health check failed after ${max_attempts} attempts"
    return 1
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f /tmp/deployment.env
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
--rollback)
                ROLLBACK_MODE=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --build-only    Only build the Docker image, don't deploy"
                echo "  --skip-tests    Skip smoke tests"
                echo "  --rollback      Rollback to previous revision"
                echo "  --help          Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Handle rollback mode
    if [ "${ROLLBACK_MODE:-false}" = "true" ]; then
        log_info "Rollback mode activated"
        rollback
        show_status
        log_info "Rollback completed!"
        exit 0
    fi
    
    # Run deployment steps
    check_prerequisites
    
    # Build image unless skipping
    if [ "${SKIP_BUILD:-false}" != "true" ]; then
        build_image
    fi
    
    if [ "${BUILD_ONLY:-false}" = "true" ]; then
        log_info "Build-only mode: skipping deployment."
        exit 0
    fi
    
    # Deploy to Kubernetes
    if ! deploy_to_k8s; then
        log_error "Deployment failed!"
        if [ "${AUTO_ROLLBACK:-true}" = "true" ]; then
            rollback
        fi
        exit 1
    fi
    
    # Monitor deployment progress
    if ! monitor_deployment; then
        log_error "Deployment monitoring failed!"
        if [ "${AUTO_ROLLBACK:-true}" = "true" ]; then
            rollback
        fi
        exit 1
    fi
    
    # Check application health
    if [ "${SKIP_HEALTH_CHECK:-false}" = "false" ]; then
        if ! check_health; then
            log_error "Health check failed!"
            if [ "${AUTO_ROLLBACK:-true}" = "true" ]; then
                rollback
            fi
            exit 1
        fi
    fi
    
    # Run smoke tests
    if [ "${SKIP_TESTS:-false}" = "false" ]; then
        if ! run_smoke_tests; then
            log_error "Smoke tests failed!"
            if [ "${AUTO_ROLLBACK:-true}" = "true" ]; then
                rollback
            fi
            exit 1
        fi
    fi
    
    # Show final status
    show_status
    
    # Save successful deployment info
    echo "LAST_SUCCESSFUL_BUILD=${BUILD_NUMBER}-${SHORT_COMMIT}" > /tmp/last_successful_deployment.env
    
    log_info "🎉 Deployment completed successfully! 🎉"
    log_info "Application is available at: kubectl -n ${NAMESPACE} port-forward svc/${APP_NAME} 8080:8080"
}

# Run main function
main "$@"
