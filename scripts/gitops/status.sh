#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=""
ALL_ENVS=false
SHOW_DETAILED=false

# Usage function
usage() {
    echo -e "${BLUE}Happy Speller Platform - GitOps Status Checker${NC}"
    echo ""
    echo "Usage: $0 [environment] [options]"
    echo ""
    echo "Arguments:"
    echo "  environment   Specific environment to check (dev, staging, prod)"
    echo ""
    echo "Options:"
    echo "  --all         Check all environments"
    echo "  --detailed    Show detailed information"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Check all environments"
    echo "  $0 dev                # Check dev environment only"
    echo "  $0 --all --detailed   # Detailed status for all environments"
    echo ""
}

# Parse command line arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            dev|staging|prod)
                ENVIRONMENT=$1
                shift
                ;;
            --all)
                ALL_ENVS=true
                shift
                ;;
            --detailed)
                SHOW_DETAILED=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown argument $1${NC}"
                usage
                exit 1
                ;;
        esac
    done
    
    # If no environment specified and not --all, default to all
    if [ -z "$ENVIRONMENT" ] && [ "$ALL_ENVS" = false ]; then
        ALL_ENVS=true
    fi
}

# Check ArgoCD application status
check_argocd_app() {
    local env=$1
    local app_name="happy-speller-$env"
    
    echo -e "${BLUE}=== ArgoCD Application: $app_name ===${NC}"
    
    if ! command -v argocd >/dev/null 2>&1; then
        echo -e "${YELLOW}[WARNING]${NC} ArgoCD CLI not available"
        return
    fi
    
    # Check if we can access the application
    if ! argocd app get "$app_name" >/dev/null 2>&1; then
        echo -e "${RED}[ERROR]${NC} Cannot access ArgoCD application $app_name"
        echo -e "${YELLOW}[HINT]${NC} Make sure you're logged into ArgoCD: argocd login <server>"
        return
    fi
    
    # Get application info
    local app_info=$(argocd app get "$app_name" -o json)
    
    # Extract key information
    local health=$(echo "$app_info" | jq -r '.status.health.status')
    local sync=$(echo "$app_info" | jq -r '.status.sync.status')
    local revision=$(echo "$app_info" | jq -r '.status.sync.revision[0:8]')
    local repo_url=$(echo "$app_info" | jq -r '.spec.source.repoURL')
    local path=$(echo "$app_info" | jq -r '.spec.source.path')
    local auto_sync=$(echo "$app_info" | jq -r '.spec.syncPolicy.automated != null')
    
    # Display status
    echo -e "Health Status: $(get_status_color "$health")$health${NC}"
    echo -e "Sync Status: $(get_status_color "$sync")$sync${NC}"
    echo -e "Revision: ${YELLOW}$revision${NC}"
    echo -e "Auto Sync: ${YELLOW}$auto_sync${NC}"
    
    if [ "$SHOW_DETAILED" = true ]; then
        echo -e "Repository: $repo_url"
        echo -e "Path: $path"
        
        # Show resources if healthy
        if [ "$health" = "Healthy" ]; then
            echo -e "\n${BLUE}Resources:${NC}"
            argocd app get "$app_name" -o json | jq -r '.status.resources[] | "  \(.kind)/\(.name): \(.status)"'
        fi
        
        # Show recent events
        echo -e "\n${BLUE}Recent Events:${NC}"
        kubectl get events -n "happy-speller-$env" --sort-by='.lastTimestamp' | tail -3
    fi
    
    echo ""
}

# Get color based on status
get_status_color() {
    local status=$1
    case $status in
        "Healthy"|"Synced")
            echo "${GREEN}"
            ;;
        "Progressing"|"OutOfSync")
            echo "${YELLOW}"
            ;;
        *)
            echo "${RED}"
            ;;
    esac
}

# Check Kubernetes deployment status
check_k8s_deployment() {
    local env=$1
    local namespace="happy-speller-$env"
    
    echo -e "${BLUE}=== Kubernetes Deployment: $namespace ===${NC}"
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        echo -e "${RED}[ERROR]${NC} Namespace $namespace does not exist"
        return
    fi
    
    # Check deployment status
    if ! kubectl get deployment happy-speller -n "$namespace" >/dev/null 2>&1; then
        echo -e "${RED}[ERROR]${NC} Deployment happy-speller not found in namespace $namespace"
        return
    fi
    
    # Get deployment info
    local deployment_info=$(kubectl get deployment happy-speller -n "$namespace" -o json)
    local replicas=$(echo "$deployment_info" | jq -r '.spec.replicas')
    local ready_replicas=$(echo "$deployment_info" | jq -r '.status.readyReplicas // 0')
    local image=$(echo "$deployment_info" | jq -r '.spec.template.spec.containers[0].image')
    
    echo -e "Replicas: ${GREEN}$ready_replicas${NC}/${BLUE}$replicas${NC}"
    echo -e "Image: ${YELLOW}$image${NC}"
    
    # Check rollout status
    local rollout_status=$(kubectl rollout status deployment/happy-speller -n "$namespace" --timeout=1s 2>&1 | head -1)
    if [[ "$rollout_status" == *"successfully rolled out"* ]]; then
        echo -e "Rollout Status: ${GREEN}Complete${NC}"
    else
        echo -e "Rollout Status: ${YELLOW}In Progress${NC}"
    fi
    
    if [ "$SHOW_DETAILED" = true ]; then
        echo -e "\n${BLUE}Pod Status:${NC}"
        kubectl get pods -n "$namespace" -l app=happy-speller -o wide
        
        echo -e "\n${BLUE}Service Status:${NC}"
        kubectl get service happy-speller -n "$namespace" 2>/dev/null || echo "Service not found"
    fi
    
    echo ""
}

# Check application health endpoint
check_app_health() {
    local env=$1
    local namespace="happy-speller-$env"
    
    echo -e "${BLUE}=== Application Health: $env ===${NC}"
    
    # Port forward to service and test health endpoint
    local port_forward_pid=""
    local health_check_result=""
    
    # Start port forward in background
    kubectl port-forward svc/happy-speller -n "$namespace" 8080:8080 >/dev/null 2>&1 &
    port_forward_pid=$!
    
    # Wait a moment for port forward to establish
    sleep 2
    
    # Test health endpoint
    if health_check_result=$(curl -s -f http://localhost:8080/healthz 2>/dev/null); then
        if echo "$health_check_result" | grep -q '"status":"ok"'; then
            echo -e "Health Check: ${GREEN}OK${NC}"
            if [ "$SHOW_DETAILED" = true ]; then
                echo -e "Response: $health_check_result"
            fi
        else
            echo -e "Health Check: ${YELLOW}Unexpected Response${NC}"
            if [ "$SHOW_DETAILED" = true ]; then
                echo -e "Response: $health_check_result"
            fi
        fi
    else
        echo -e "Health Check: ${RED}FAILED${NC}"
    fi
    
    # Clean up port forward
    if [ -n "$port_forward_pid" ]; then
        kill $port_forward_pid 2>/dev/null || true
    fi
    
    echo ""
}

# Show current image tags across environments
show_image_tags() {
    echo -e "${BLUE}=== Current Image Tags ===${NC}"
    
    for env in dev staging prod; do
        local kustomization_file="gitops/environments/$env/kustomization.yaml"
        if [ -f "$kustomization_file" ]; then
            local tag=$(grep "newTag:" "$kustomization_file" | sed 's/.*newTag: *//')
            echo -e "$env: ${YELLOW}$tag${NC}"
        else
            echo -e "$env: ${RED}Configuration not found${NC}"
        fi
    done
    
    echo ""
}

# Main function
main() {
    parse_args "$@"
    
    echo -e "${BLUE}Happy Speller Platform - GitOps Status${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    
    # Show current image tags
    show_image_tags
    
    # Check specific environment or all
    if [ "$ALL_ENVS" = true ]; then
        for env in dev staging prod; do
            check_argocd_app "$env"
            check_k8s_deployment "$env"
            if [ "$SHOW_DETAILED" = true ]; then
                check_app_health "$env"
            fi
        done
    else
        check_argocd_app "$ENVIRONMENT"
        check_k8s_deployment "$ENVIRONMENT"
        if [ "$SHOW_DETAILED" = true ]; then
            check_app_health "$ENVIRONMENT"
        fi
    fi
    
    echo -e "${GREEN}Status check completed!${NC}"
    echo ""
    echo -e "${BLUE}Quick Access:${NC}"
    echo "ArgoCD UI: http://localhost:30080 (kubectl port-forward svc/argocd-server -n argocd 8080:443)"
    echo "Dev App: kubectl port-forward svc/happy-speller -n happy-speller-dev 8080:8080"
    echo "Staging App: kubectl port-forward svc/happy-speller -n happy-speller-staging 8080:8080"
    echo "Prod App: kubectl port-forward svc/happy-speller -n happy-speller-prod 8080:8080"
}

# Run main function with all arguments
main "$@"