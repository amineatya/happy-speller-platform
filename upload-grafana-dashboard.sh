#!/bin/bash

# Grafana Configuration
GRAFANA_URL="http://192.168.50.97:3000"
GRAFANA_USER="admin"  # Default admin user
GRAFANA_PASS="admin"  # Default password (change if different)

echo "📊 Uploading Happy Speller Platform Dashboard to Grafana"
echo "🌐 Grafana URL: ${GRAFANA_URL}"

# Test Grafana connectivity
echo "🔍 Testing Grafana connectivity..."
if curl -s --connect-timeout 5 "${GRAFANA_URL}/api/health" > /dev/null; then
    echo "✅ Grafana is accessible"
else
    echo "❌ Cannot connect to Grafana at ${GRAFANA_URL}"
    echo "💡 Please check if Grafana is running and accessible"
    exit 1
fi

# Check if dashboard file exists
DASHBOARD_FILE="grafana-dashboard.json"
if [ ! -f "${DASHBOARD_FILE}" ]; then
    echo "❌ Dashboard file ${DASHBOARD_FILE} not found"
    exit 1
fi

echo "📤 Uploading dashboard..."

# Upload dashboard to Grafana
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
  -d @"${DASHBOARD_FILE}" \
  "${GRAFANA_URL}/api/dashboards/db")

# Check if upload was successful
if echo "$RESPONSE" | grep -q '"status":"success"'; then
    echo "✅ Dashboard uploaded successfully!"
    
    # Extract dashboard URL if possible
    if echo "$RESPONSE" | grep -q '"url"'; then
        DASHBOARD_URL=$(echo "$RESPONSE" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        echo "🔗 Dashboard URL: ${GRAFANA_URL}${DASHBOARD_URL}"
    fi
    
elif echo "$RESPONSE" | grep -q '"message"'; then
    echo "⚠️ Upload response:"
    echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    
    # Check if it's a credentials issue
    if echo "$RESPONSE" | grep -q -i "unauthorized\|invalid.*credentials"; then
        echo ""
        echo "🔐 Authentication failed. Try these steps:"
        echo "1. Go to ${GRAFANA_URL}/login"
        echo "2. Login with your credentials"  
        echo "3. Update GRAFANA_USER and GRAFANA_PASS in this script"
        echo "4. Run the script again"
    fi
    
else
    echo "❌ Upload failed. Response:"
    echo "$RESPONSE"
fi

echo ""
echo "📋 Alternative: Manual Upload"
echo "1. Go to ${GRAFANA_URL}/dashboard/import"
echo "2. Upload the file: ${DASHBOARD_FILE}"
echo "3. Click 'Load' and then 'Import'"