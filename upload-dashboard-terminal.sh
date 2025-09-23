#!/bin/bash

# Direct Grafana Dashboard Upload from Terminal
# Happy Speller Platform - Comprehensive Metrics

GRAFANA_URL="http://192.168.50.97:3000"
DASHBOARD_FILE="grafana-detailed-dashboard.json"

echo "🚀 Uploading Dashboard from Terminal"
echo "📊 Dashboard: ${DASHBOARD_FILE}"
echo "🌐 Grafana: ${GRAFANA_URL}"
echo ""

# Check if dashboard file exists
if [ ! -f "${DASHBOARD_FILE}" ]; then
    echo "❌ Dashboard file not found: ${DASHBOARD_FILE}"
    echo "📁 Current directory: $(pwd)"
    echo "📋 Available files:"
    ls -la *.json 2>/dev/null || echo "   No JSON files found"
    exit 1
fi

# Check Grafana connectivity
echo "🔍 Testing Grafana connection..."
if ! curl -s --connect-timeout 5 "${GRAFANA_URL}/api/health" > /dev/null; then
    echo "❌ Cannot connect to Grafana at ${GRAFANA_URL}"
    echo "💡 Make sure Grafana is running and accessible"
    exit 1
fi

echo "✅ Grafana is accessible"
echo ""

# Prompt for credentials
echo "🔐 Grafana Login Required:"
read -p "Username: " GRAFANA_USER
read -s -p "Password: " GRAFANA_PASS
echo ""
echo ""

# Upload dashboard
echo "📤 Uploading dashboard..."
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
  -d @"${DASHBOARD_FILE}" \
  "${GRAFANA_URL}/api/dashboards/db")

# Check response
if echo "$RESPONSE" | grep -q '"status":"success"'; then
    echo "✅ Dashboard uploaded successfully!"
    
    # Extract dashboard info
    DASHBOARD_URL=$(echo "$RESPONSE" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
    DASHBOARD_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | cut -d':' -f2)
    
    echo ""
    echo "🎉 SUCCESS! Your comprehensive dashboard is live!"
    echo ""
    echo "📊 Dashboard Info:"
    echo "   • Name: Happy Speller Platform - Comprehensive Metrics"  
    echo "   • Panels: 24 monitoring panels"
    echo "   • ID: ${DASHBOARD_ID}"
    echo "   • URL: ${GRAFANA_URL}${DASHBOARD_URL}"
    echo ""
    echo "🔗 Quick Access:"
    echo "   ${GRAFANA_URL}${DASHBOARD_URL}"
    echo ""
    echo "🎯 Features:"
    echo "   ✅ Real-time infrastructure monitoring"
    echo "   ✅ Kubernetes cluster health"
    echo "   ✅ Application performance metrics"
    echo "   ✅ Jenkins CI/CD monitoring"  
    echo "   ✅ 15-second auto-refresh"
    echo ""
    
elif echo "$RESPONSE" | grep -q '"message"'; then
    ERROR_MSG=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    echo "❌ Upload failed: ${ERROR_MSG}"
    
    if echo "$ERROR_MSG" | grep -q -i "unauthorized\|invalid.*credentials"; then
        echo ""
        echo "🔐 Authentication failed. Please check your credentials."
        echo "💡 Default Grafana credentials are often:"
        echo "   Username: admin"
        echo "   Password: admin (or password)"
    fi
    
else
    echo "❌ Upload failed with unexpected response:"
    echo "$RESPONSE"
fi

echo ""
echo "📁 Dashboard file location: $(pwd)/${DASHBOARD_FILE}"