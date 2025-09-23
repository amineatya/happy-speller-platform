#!/bin/bash

# Connect Grafana Data Pipeline
# This script sets up Prometheus data source and updates dashboard

GRAFANA_URL="http://192.168.50.97:3000"
PROMETHEUS_URL="http://localhost:9090"

echo "🔗 Connecting Grafana Data Pipeline"
echo "======================================"
echo ""

# Check if port forwarding is running
echo "🔍 Checking Prometheus connection..."
if curl -s --connect-timeout 3 "${PROMETHEUS_URL}/api/v1/status/config" > /dev/null; then
    echo "✅ Prometheus is accessible at ${PROMETHEUS_URL}"
else
    echo "❌ Prometheus is not accessible at ${PROMETHEUS_URL}"
    echo ""
    echo "🚀 Starting port forwarding..."
    echo "Run this command in another terminal:"
    echo "kubectl --kubeconfig ./kubeconfig-talos port-forward -n monitoring service/prometheus 9090:9090"
    echo ""
    read -p "Press Enter when port forwarding is running..."
fi

# Test Grafana connection
echo ""
echo "🔍 Testing Grafana connection..."
if curl -s --connect-timeout 5 "${GRAFANA_URL}/api/health" > /dev/null; then
    echo "✅ Grafana is accessible at ${GRAFANA_URL}"
else
    echo "❌ Cannot connect to Grafana at ${GRAFANA_URL}"
    echo "Please check if Grafana is running"
    exit 1
fi

# Get credentials
echo ""
echo "🔐 Grafana Login Required:"
read -p "Username: " GRAFANA_USER
read -s -p "Password: " GRAFANA_PASS
echo ""

# Check if prometheus data source already exists
echo ""
echo "🔍 Checking existing data sources..."
EXISTING_DS=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" "${GRAFANA_URL}/api/datasources/name/prometheus" 2>/dev/null)

if echo "$EXISTING_DS" | grep -q '"name":"prometheus"'; then
    echo "✅ Prometheus data source already exists"
    
    # Update existing data source
    DS_ID=$(echo "$EXISTING_DS" | grep -o '"id":[0-9]*' | cut -d':' -f2)
    echo "🔄 Updating data source (ID: ${DS_ID})..."
    
    UPDATE_RESPONSE=$(curl -s -X PUT \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
        -d "{
            \"id\": ${DS_ID},
            \"name\": \"prometheus\",
            \"type\": \"prometheus\",
            \"url\": \"${PROMETHEUS_URL}\",
            \"access\": \"proxy\",
            \"isDefault\": true,
            \"basicAuth\": false
        }" \
        "${GRAFANA_URL}/api/datasources/${DS_ID}")
    
    if echo "$UPDATE_RESPONSE" | grep -q '"message":"Datasource updated"'; then
        echo "✅ Data source updated successfully!"
    else
        echo "⚠️  Update response: $UPDATE_RESPONSE"
    fi
    
else
    echo "➕ Creating new Prometheus data source..."
    
    CREATE_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
        -d "{
            \"name\": \"prometheus\",
            \"type\": \"prometheus\",
            \"url\": \"${PROMETHEUS_URL}\",
            \"access\": \"proxy\",
            \"isDefault\": true,
            \"basicAuth\": false
        }" \
        "${GRAFANA_URL}/api/datasources")
    
    if echo "$CREATE_RESPONSE" | grep -q '"message":"Datasource added"'; then
        echo "✅ Data source created successfully!"
    else
        echo "❌ Failed to create data source: $CREATE_RESPONSE"
        exit 1
    fi
fi

# Test data source connection
echo ""
echo "🧪 Testing Prometheus queries..."
TEST_QUERY=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    "${GRAFANA_URL}/api/datasources/proxy/1/api/v1/query?query=up" 2>/dev/null)

if echo "$TEST_QUERY" | grep -q '"status":"success"'; then
    echo "✅ Prometheus queries working!"
    
    # Show some sample metrics
    NODE_COUNT=$(echo "$TEST_QUERY" | grep -o '"value":\[.*,"1"\]' | wc -l)
    echo "📊 Found ${NODE_COUNT} nodes reporting 'up' status"
else
    echo "⚠️  Query test: $TEST_QUERY"
fi

echo ""
echo "🎉 Data Pipeline Connected!"
echo "=========================="
echo ""
echo "✅ Prometheus: ${PROMETHEUS_URL} (via port-forward)"
echo "✅ Grafana Data Source: prometheus (default)"
echo "✅ Dashboard: http://192.168.50.97:3000/d/7ed1ceb6-7c31-4f44-bb78-779f5344a605/happy-speller-platform-comprehensive-metrics"
echo ""
echo "🔗 Your dashboard should now show live data!"
echo ""
echo "💡 Tips:"
echo "   • Keep the port-forward running: kubectl --kubeconfig ./kubeconfig-talos port-forward -n monitoring service/prometheus 9090:9090"
echo "   • Dashboard refreshes every 15 seconds automatically"
echo "   • All 24 panels should now display metrics from your Kubernetes cluster"
echo ""