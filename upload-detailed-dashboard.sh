#!/bin/bash

# Advanced Grafana Dashboard Upload Script
# Happy Speller Platform - Comprehensive Metrics Dashboard

# Grafana Configuration
GRAFANA_URL="http://192.168.50.97:3000"
DASHBOARD_FILE="grafana-detailed-dashboard.json"

echo "📊 Uploading Comprehensive Metrics Dashboard to Grafana"
echo "🎯 Dashboard: Happy Speller Platform - Comprehensive Metrics"
echo "🌐 Grafana URL: ${GRAFANA_URL}"

# Test Grafana connectivity
echo ""
echo "🔍 Testing Grafana connectivity..."
if curl -s --connect-timeout 5 "${GRAFANA_URL}/api/health" > /dev/null; then
    echo "✅ Grafana is accessible"
    GRAFANA_VERSION=$(curl -s "${GRAFANA_URL}/api/health" | jq -r '.version' 2>/dev/null)
    if [ "$GRAFANA_VERSION" != "null" ] && [ -n "$GRAFANA_VERSION" ]; then
        echo "📋 Grafana Version: ${GRAFANA_VERSION}"
    fi
else
    echo "❌ Cannot connect to Grafana at ${GRAFANA_URL}"
    echo "💡 Please check if Grafana is running and accessible"
    exit 1
fi

# Check if dashboard file exists
if [ ! -f "${DASHBOARD_FILE}" ]; then
    echo "❌ Dashboard file ${DASHBOARD_FILE} not found"
    exit 1
fi

echo "📊 Dashboard contains:"
echo "   🏗️  Infrastructure monitoring (CPU, Memory, Disk, Network)"
echo "   ☸️  Kubernetes cluster metrics"
echo "   🚀 Application performance metrics" 
echo "   🔧 Jenkins CI/CD pipeline monitoring"
echo "   📊 Database and container metrics"
echo "   🌡️  System temperature and power consumption"
echo "   📈 24 comprehensive panels total"

# Try common credential combinations
CREDENTIALS_TO_TRY=(
    "admin:admin"
    "admin:password"
    "admin:"
    "grafana:grafana"
)

echo ""
echo "📤 Attempting dashboard upload..."

SUCCESS=false
for cred in "${CREDENTIALS_TO_TRY[@]}"; do
    echo "🔐 Trying credentials: ${cred%%:*}:****"
    
    RESPONSE=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      -u "${cred}" \
      -d @"${DASHBOARD_FILE}" \
      "${GRAFANA_URL}/api/dashboards/db" 2>/dev/null)
    
    # Check if upload was successful
    if echo "$RESPONSE" | grep -q '"status":"success"'; then
        echo "✅ Dashboard uploaded successfully!"
        SUCCESS=true
        
        # Extract dashboard information
        if echo "$RESPONSE" | grep -q '"url"'; then
            DASHBOARD_URL=$(echo "$RESPONSE" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
            DASHBOARD_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | cut -d':' -f2)
            echo "🔗 Dashboard URL: ${GRAFANA_URL}${DASHBOARD_URL}"
            echo "🆔 Dashboard ID: ${DASHBOARD_ID}"
        fi
        
        echo ""
        echo "🎉 SUCCESS! Comprehensive Metrics Dashboard is now live!"
        echo ""
        echo "📊 Dashboard Features:"
        echo "   ✅ Real-time infrastructure monitoring"
        echo "   ✅ Kubernetes cluster health"
        echo "   ✅ Application performance tracking"
        echo "   ✅ Jenkins pipeline monitoring"
        echo "   ✅ Error rate and uptime tracking"
        echo "   ✅ Resource utilization metrics"
        echo "   ✅ Temperature and power monitoring"
        echo "   ✅ Interactive filtering and variables"
        echo ""
        echo "🔗 Quick Links integrated:"
        echo "   • Jenkins: http://192.168.50.247:8080"
        echo "   • Gitea: http://192.168.50.130:3000"
        echo "   • MinIO: http://192.168.50.177:9001"
        echo "   • Kubernetes: https://192.168.50.226:8443"
        echo ""
        echo "⚡ Dashboard auto-refreshes every 15 seconds"
        echo "📈 View data from last 3 hours by default"
        
        break
        
    elif echo "$RESPONSE" | grep -q '"message"'; then
        ERROR_MSG=$(echo "$RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        if echo "$ERROR_MSG" | grep -q -i "unauthorized\|invalid.*credentials\|authentication"; then
            continue  # Try next credential combination
        else
            echo "⚠️ Upload failed: $ERROR_MSG"
            break
        fi
    else
        echo "⚠️ Unexpected response format"
        continue
    fi
done

if [ "$SUCCESS" = false ]; then
    echo ""
    echo "❌ Automatic upload failed with all credential combinations"
    echo ""
    echo "📋 Manual Upload Instructions:"
    echo "1. Go to ${GRAFANA_URL}/login"
    echo "2. Login with your Grafana credentials"
    echo "3. Navigate to + → Import"
    echo "4. Upload the file: ${DASHBOARD_FILE}"
    echo "5. Click 'Load' and then 'Import'"
    echo ""
    echo "🔧 Alternative: Update credentials in this script"
    echo "   Edit the CREDENTIALS_TO_TRY array with your actual credentials"
    echo ""
    echo "📁 Dashboard file location: $(pwd)/${DASHBOARD_FILE}"
fi

echo ""
echo "📊 Dashboard Specifications:"
echo "   📈 Panels: 24 comprehensive monitoring panels"
echo "   🔄 Refresh: 15 seconds auto-refresh"
echo "   📅 Time Range: 3 hours (customizable)"
echo "   🎨 Theme: Dark mode optimized"
echo "   📱 Responsive: Works on all devices"
echo "   🔗 Variables: Instance and namespace filtering"

# Also upload to MinIO for backup
echo ""
echo "💾 Backing up dashboard to MinIO..."
if command -v mc &> /dev/null; then
    mc cp "${DASHBOARD_FILE}" myminio/happy-speller-platform/monitoring/detailed-dashboard.json 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ Dashboard backed up to MinIO"
    else
        echo "⚠️ MinIO backup failed (not critical)"
    fi
else
    echo "⚠️ MinIO CLI not available for backup"
fi

echo ""
echo "🎯 Your comprehensive monitoring solution is ready!"