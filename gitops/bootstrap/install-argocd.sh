#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_VERSION="v2.8.4"
NAMESPACE="argocd"

echo -e "${BLUE}[INFO]${NC} Installing ArgoCD for Happy Speller Platform GitOps"
echo -e "${BLUE}[INFO]${NC} ArgoCD Version: ${ARGOCD_VERSION}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Cannot access Kubernetes cluster"
    echo -e "${YELLOW}[HINT]${NC} Check your kubeconfig and cluster connectivity"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Creating ArgoCD namespace..."
kubectl apply -f argocd-install.yaml

echo -e "${BLUE}[INFO]${NC} Installing ArgoCD ${ARGOCD_VERSION}..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

echo -e "${BLUE}[INFO]${NC} Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Patch ArgoCD server service to NodePort for easier access
echo -e "${BLUE}[INFO]${NC} Configuring ArgoCD server service..."
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"port":443,"targetPort":8080,"nodePort":30080}]}}'

# Configure ArgoCD to work without TLS (for easier local development)
kubectl patch deployment argocd-server -n argocd --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--insecure"
  }
]'

# Wait for the patched deployment
echo -e "${BLUE}[INFO]${NC} Waiting for ArgoCD server to restart..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

# Get initial admin password
echo -e "${BLUE}[INFO]${NC} Retrieving ArgoCD admin password..."
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Configure ArgoCD CLI access
echo -e "${BLUE}[INFO]${NC} Setting up ArgoCD CLI configuration..."
if command -v argocd &> /dev/null; then
    # Try to login (this might fail if ArgoCD isn't fully ready yet)
    for i in {1..10}; do
        if argocd login localhost:30080 --username admin --password "${ADMIN_PASSWORD}" --insecure; then
            break
        fi
        echo -e "${YELLOW}[WARN]${NC} ArgoCD not ready yet, retrying in 10 seconds..."
        sleep 10
    done
else
    echo -e "${YELLOW}[WARN]${NC} ArgoCD CLI not installed. Install with:"
    echo "  curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
    echo "  chmod +x /usr/local/bin/argocd"
fi

echo ""
echo -e "${GREEN}[SUCCESS]${NC} ArgoCD installation completed!"
echo ""
echo -e "${BLUE}Access Information:${NC}"
echo "  ArgoCD UI: http://localhost:30080"
echo "  Username:  admin"
echo "  Password:  ${ADMIN_PASSWORD}"
echo ""
echo -e "${BLUE}Quick Access:${NC}"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then visit: https://localhost:8080"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Access ArgoCD UI and change admin password"
echo "  2. Deploy applications: kubectl apply -f ../applications/"
echo "  3. Configure repositories in ArgoCD UI"
echo ""