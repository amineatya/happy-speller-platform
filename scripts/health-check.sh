#!/bin/bash

# Health Check Script for Happy Speller
# This script performs comprehensive health checks on the deployed application

set -e

# Configuration
NAMESPACE="demo"
APP_NAME="happy-speller"
HEALTH_ENDPOINT="/healthz"
VERSION_ENDPOINT="/api/version"

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

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
}

# Get application URL
get_app_url() {
    local service_name="${APP_NAME}"
    local service_port=$(kubectl get service "${service_name}" -n "${NAMESPACE}" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "8080")
    
    # Try to get external IP or use port-forward
    local external_ip=$(kubectl get service "${service_name}" -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "${external_ip}" ]; then
        echo "http://${external_ip}:${service_port}"
    else
        # Use port-forward as fallback
        echo "http://localhost:8080"
    fi
}

# Check if application is running
check_app_running() {
    log_info "Checking if application is running..."
    
    local pods=$(kubectl get pods -n "${NAMESPACE}" -l app="${APP_NAME}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "${pods}" ]; then
        log_error "No pods found for application '${APP_NAME}' in namespace '${NAMESPACE}'"
        return 1
    fi
    
    local running_pods=0
    for pod in ${pods}; do
        local status=$(kubectl get pod "${pod}" -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [ "${status}" = "Running" ]; then
            ((running_pods++))
        fi
    done
    
    if [ ${running_pods} -eq 0 ]; then
        log_error "No running pods found"
        return 1
    fi
    
    log_info "Found ${running_pods} running pod(s)"
    return 0
}

# Check health endpoint
check_health_endpoint() {
    log_info "Checking health endpoint..."
    
    local app_url=$(get_app_url)
    local health_url="${app_url}${HEALTH_ENDPOINT}"
    
    # Start port-forward if needed
    local port_forward_pid=""
    if [[ "${app_url}" == "http://localhost:8080" ]]; then
        log_info "Starting port-forward to access the application..."
        kubectl port-forward -n "${NAMESPACE}" service/"${APP_NAME}" 8080:8080 > /dev/null 2>&1 &
        port_forward_pid=$!
        sleep 5
    fi
    
    # Test health endpoint
    local health_response=$(curl -s -w "%{http_code}" "${health_url}" 2>/dev/null || echo "000")
    local http_code="${health_response: -3}"
    local response_body="${health_response%???}"
    
    # Clean up port-forward
    if [ -n "${port_forward_pid}" ]; then
        kill "${port_forward_pid}" 2>/dev/null || true
    fi
    
    if [ "${http_code}" = "200" ]; then
        if echo "${response_body}" | grep -q '"status":"ok"'; then
            log_info "Health endpoint is healthy"
            return 0
        else
            log_error "Health endpoint returned unexpected response: ${response_body}"
            return 1
        fi
    else
        log_error "Health endpoint returned HTTP ${http_code}"
        return 1
    fi
}

# Check version endpoint
check_version_endpoint() {
    log_info "Checking version endpoint..."
    
    local app_url=$(get_app_url)
    local version_url="${app_url}${VERSION_ENDPOINT}"
    
    # Start port-forward if needed
    local port_forward_pid=""
    if [[ "${app_url}" == "http://localhost:8080" ]]; then
        log_info "Starting port-forward to access the application..."
        kubectl port-forward -n "${NAMESPACE}" service/"${APP_NAME}" 8080:8080 > /dev/null 2>&1 &
        port_forward_pid=$!
        sleep 5
    fi
    
    # Test version endpoint
    local version_response=$(curl -s -w "%{http_code}" "${version_url}" 2>/dev/null || echo "000")
    local http_code="${version_response: -3}"
    local response_body="${version_response%???}"
    
    # Clean up port-forward
    if [ -n "${port_forward_pid}" ]; then
        kill "${port_forward_pid}" 2>/dev/null || true
    fi
    
    if [ "${http_code}" = "200" ]; then
        if echo "${response_body}" | grep -q '"name":"Happy Speller"'; then
            log_info "Version endpoint is working"
            echo "Response: ${response_body}"
            return 0
        else
            log_error "Version endpoint returned unexpected response: ${response_body}"
            return 1
        fi
    else
        log_error "Version endpoint returned HTTP ${http_code}"
        return 1
    fi
}

# Check resource usage
check_resource_usage() {
    log_info "Checking resource usage..."
    
    kubectl top pods -n "${NAMESPACE}" -l app="${APP_NAME}" 2>/dev/null || {
        log_warn "Metrics server not available, skipping resource check"
        return 0
    }
    
    log_info "Resource usage:"
    kubectl top pods -n "${NAMESPACE}" -l app="${APP_NAME}"
}

# Check logs for errors
check_logs() {
    log_info "Checking application logs for errors..."
    
    local pods=$(kubectl get pods -n "${NAMESPACE}" -l app="${APP_NAME}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "${pods}" ]; then
        log_error "No pods found to check logs"
        return 1
    fi
    
    for pod in ${pods}; do
        log_info "Checking logs for pod: ${pod}"
        local error_count=$(kubectl logs "${pod}" -n "${NAMESPACE}" --since=1h 2>/dev/null | grep -i error | wc -l || echo "0")
        
        if [ "${error_count}" -gt 0 ]; then
            log_warn "Found ${error_count} error(s) in logs for pod ${pod}"
            kubectl logs "${pod}" -n "${NAMESPACE}" --since=1h | grep -i error | tail -5
        else
            log_info "No errors found in logs for pod ${pod}"
        fi
    done
}

# Generate health report
generate_report() {
    local report_file="health-report-$(date +%Y%m%d-%H%M%S).txt"
    
    log_info "Generating health report: ${report_file}"
    
    {
        echo "Happy Speller Health Report"
        echo "Generated: $(date)"
        echo "Namespace: ${NAMESPACE}"
        echo "Application: ${APP_NAME}"
        echo ""
        echo "=== Pod Status ==="
        kubectl get pods -n "${NAMESPACE}" -l app="${APP_NAME}"
        echo ""
        echo "=== Service Status ==="
        kubectl get services -n "${NAMESPACE}" -l app="${APP_NAME}"
        echo ""
        echo "=== Resource Usage ==="
        kubectl top pods -n "${NAMESPACE}" -l app="${APP_NAME}" 2>/dev/null || echo "Metrics not available"
        echo ""
        echo "=== Recent Logs ==="
        local pods=$(kubectl get pods -n "${NAMESPACE}" -l app="${APP_NAME}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ -n "${pods}" ]; then
            kubectl logs "${pods}" -n "${NAMESPACE}" --tail=20
        fi
    } > "${report_file}"
    
    log_info "Health report saved to: ${report_file}"
}

# Main health check function
main() {
    log_info "Starting health check for Happy Speller application..."
    
    local exit_code=0
    
    # Check prerequisites
    check_kubectl
    
    # Run health checks
    if ! check_app_running; then
        exit_code=1
    fi
    
    if ! check_health_endpoint; then
        exit_code=1
    fi
    
    if ! check_version_endpoint; then
        exit_code=1
    fi
    
    check_resource_usage
    check_logs
    
    # Generate report
    generate_report
    
    if [ ${exit_code} -eq 0 ]; then
        log_info "All health checks passed!"
    else
        log_error "Some health checks failed!"
    fi
    
    exit ${exit_code}
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --namespace NAMESPACE    Kubernetes namespace (default: demo)"
    echo "  --app-name NAME          Application name (default: happy-speller)"
    echo "  --report-only            Only generate report, skip checks"
    echo "  --help                   Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --namespace production --app-name happy-speller"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --app-name)
            APP_NAME="$2"
            shift 2
            ;;
        --report-only)
            generate_report
            exit 0
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

# Run main function
main
