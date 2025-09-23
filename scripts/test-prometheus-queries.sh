#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Prometheus configuration
PROMETHEUS_POD=$(kubectl get pods -n monitoring -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
PROMETHEUS_URL="http://localhost:9090"

echo -e "${BLUE}Happy Speller Platform - Prometheus Query Tester${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

if [ -z "$PROMETHEUS_POD" ]; then
    echo -e "${RED}Error: Prometheus pod not found${NC}"
    exit 1
fi

echo -e "${GREEN}Using Prometheus pod: $PROMETHEUS_POD${NC}"
echo ""

# Function to run query and display result
run_query() {
    local name=$1
    local query=$2
    local description=$3
    
    echo -e "${BLUE}📊 $name${NC}"
    echo -e "${YELLOW}Query:${NC} $query"
    echo -e "${YELLOW}Description:${NC} $description"
    
    # URL encode the query
    local encoded_query=$(echo "$query" | sed 's/ /%20/g' | sed 's/=/%3D/g' | sed 's/{/%7B/g' | sed 's/}/%7D/g' | sed 's/"/%22/g')
    
    # Execute query
    local result=$(kubectl exec -n monitoring "$PROMETHEUS_POD" -- wget -q -O- "http://localhost:9090/api/v1/query?query=$encoded_query" 2>/dev/null || echo '{"error":"query failed"}')
    
    # Parse and display result
    if echo "$result" | grep -q '"status":"success"'; then
        local value_count=$(echo "$result" | jq '.data.result | length' 2>/dev/null || echo "0")
        if [ "$value_count" -gt 0 ]; then
            echo -e "${GREEN}✅ Result: $value_count metrics found${NC}"
            # Show first few results
            echo "$result" | jq '.data.result[0:3] | .[] | "\(.metric) = \(.value[1])"' 2>/dev/null | head -3
        else
            echo -e "${YELLOW}⚠️ Result: No data returned${NC}"
        fi
    else
        echo -e "${RED}❌ Query failed${NC}"
    fi
    echo ""
}

echo -e "${BLUE}🚀 Testing Key Monitoring Queries${NC}"
echo ""

# System Health Queries
run_query "System Health" "up" "Shows which services are up (1) or down (0)"
run_query "Services Count" "count(up == 1)" "Number of healthy services"
run_query "Running Pods" "count(kube_pod_status_phase{phase=\"Running\"})" "Total running pods in cluster"

# Application Specific
run_query "Happy Speller Health" "avg(kube_pod_status_ready{namespace=\"demo\"})" "Demo namespace pod readiness average"
run_query "ArgoCD Health" "avg(kube_pod_status_ready{namespace=\"argocd\"})" "ArgoCD namespace pod readiness"

# Resource Usage
run_query "Node CPU Usage" "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)" "Average CPU usage percentage"
run_query "Node Memory Usage" "(1 - (avg(node_memory_MemAvailable_bytes) / avg(node_memory_MemTotal_bytes))) * 100" "Average memory usage percentage"

# Kubernetes Health
run_query "Total Pods" "count(kube_pod_info)" "Total pods in cluster"
run_query "Failed Pods" "count(kube_pod_status_phase{phase=\"Failed\"})" "Number of failed pods"
run_query "Pending Pods" "count(kube_pod_status_phase{phase=\"Pending\"})" "Number of pending pods"

echo -e "${GREEN}🎯 Query Testing Complete!${NC}"
echo ""
echo -e "${BLUE}📖 Next Steps:${NC}"
echo "1. Access Prometheus UI: http://192.168.50.183:30090"
echo "2. Go to 'Graph' tab"
echo "3. Copy any query from prometheus-queries.md"
echo "4. Click 'Execute' to see results"
echo ""
echo -e "${BLUE}📊 Quick Dashboard Queries:${NC}"
echo "- up"
echo "- count(up == 1)"
echo "- count(kube_pod_status_phase{phase=\"Running\"})"
echo "- avg(kube_pod_status_ready{namespace=\"demo\"})"
echo ""