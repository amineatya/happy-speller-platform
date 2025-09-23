#!/bin/bash

echo "🔍 Debugging Grafana Dashboard Data Flow"
echo "========================================="
echo ""

# Test 1: Check if port forwarding is working
echo "1️⃣ Testing Prometheus direct access..."
if curl -s --connect-timeout 3 "http://localhost:9090/api/v1/query?query=up" >/dev/null; then
    echo "✅ Prometheus is accessible at localhost:9090"
    
    # Show sample data
    NODES=$(curl -s "http://localhost:9090/api/v1/query?query=up" | jq -r '.data.result[] | select(.value[1]=="1") | .metric.instance' 2>/dev/null | wc -l)
    echo "📊 Found $NODES active targets"
else
    echo "❌ Cannot reach Prometheus at localhost:9090"
    echo "🚀 Make sure port forwarding is running:"
    echo "   kubectl --kubeconfig ./kubeconfig-talos port-forward -n monitoring service/prometheus 9090:9090"
    exit 1
fi

echo ""

# Test 2: Check specific metrics used by dashboard
echo "2️⃣ Testing dashboard metrics..."

METRICS_TO_TEST=(
    "up"
    "kube_node_info" 
    "node_cpu_seconds_total"
    "node_memory_MemTotal_bytes"
    "kube_pod_status_phase"
)

for metric in "${METRICS_TO_TEST[@]}"; do
    RESULT=$(curl -s "http://localhost:9090/api/v1/query?query=$metric" | jq -r '.data.result | length' 2>/dev/null)
    if [[ "$RESULT" -gt 0 ]]; then
        echo "✅ $metric: $RESULT series"
    else
        echo "❌ $metric: No data"
    fi
done

echo ""

# Test 3: Check Grafana connectivity
echo "3️⃣ Testing Grafana access..."
if curl -s --connect-timeout 5 "http://192.168.50.97:3000/api/health" >/dev/null; then
    echo "✅ Grafana is accessible"
else
    echo "❌ Cannot reach Grafana"
    exit 1
fi

echo ""

# Test 4: Try to access dashboard directly
echo "4️⃣ Dashboard troubleshooting..."
echo "🔗 Your dashboard URL:"
echo "   http://192.168.50.97:3000/d/7ed1ceb6-7c31-4f44-bb78-779f5344a605/happy-speller-platform-comprehensive-metrics"

echo ""
echo "🛠️ Manual troubleshooting steps:"
echo ""
echo "A) In Grafana, go to Configuration → Data Sources"
echo "   • Check if 'prometheus' data source exists"
echo "   • URL should be: http://localhost:9090"
echo "   • Click 'Save & Test' - should show green success"
echo ""
echo "B) In your dashboard:"
echo "   • Click on any panel title → Edit"
echo "   • Check the 'Data source' dropdown at top"
echo "   • Should be set to 'prometheus'"
echo "   • Try running a simple query like: up"
echo ""
echo "C) If panels show 'N/A' or no data:"
echo "   • Check time range (top right) - set to 'Last 5 minutes'"
echo "   • Make sure auto-refresh is enabled (top right)"
echo "   • Try refreshing the dashboard (Ctrl+R)"

echo ""
echo "🔧 Quick fixes to try:"

# Create a simple test dashboard
echo ""
echo "Creating a minimal test dashboard..."

cat > test-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Test Dashboard",
    "tags": ["test"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Simple UP Query",
        "type": "stat",
        "targets": [
          {
            "expr": "up",
            "datasource": {
              "type": "prometheus",
              "uid": "prometheus"
            }
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      }
    ],
    "time": {
      "from": "now-5m",
      "to": "now"
    },
    "refresh": "5s"
  },
  "overwrite": true
}
EOF

echo "📤 Test dashboard created: test-dashboard.json"
echo ""
echo "💡 To upload test dashboard:"
echo "   1. Go to Grafana → + → Import"
echo "   2. Upload test-dashboard.json"
echo "   3. If this shows data, the issue is with the main dashboard configuration"

echo ""
echo "🎯 Most likely issues:"
echo "   • Dashboard data source reference is incorrect"
echo "   • Time range is wrong (try 'Last 5 minutes')"
echo "   • Auto-refresh is disabled"
echo "   • Grafana can't proxy to localhost:9090"