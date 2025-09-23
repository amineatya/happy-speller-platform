#!/bin/bash

echo "🔧 Fixing Dashboard Data Source Configuration"
echo "============================================="
echo ""

# Get credentials for Grafana
echo "🔐 Enter Grafana credentials to fix data source:"
read -p "Username: " GRAFANA_USER
read -s -p "Password: " GRAFANA_PASS
echo ""
echo ""

GRAFANA_URL="http://192.168.50.97:3000"

# Step 1: Get the actual data source UID from Grafana
echo "1️⃣ Getting current data source configuration..."
DS_RESPONSE=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" "${GRAFANA_URL}/api/datasources" 2>/dev/null)

if echo "$DS_RESPONSE" | grep -q "Invalid username or password"; then
    echo "❌ Authentication failed. Please check your credentials."
    exit 1
fi

# Extract prometheus data source info
PROMETHEUS_UID=$(echo "$DS_RESPONSE" | jq -r '.[] | select(.name=="prometheus") | .uid' 2>/dev/null)
PROMETHEUS_ID=$(echo "$DS_RESPONSE" | jq -r '.[] | select(.name=="prometheus") | .id' 2>/dev/null)

if [[ "$PROMETHEUS_UID" != "null" && -n "$PROMETHEUS_UID" ]]; then
    echo "✅ Found Prometheus data source:"
    echo "   • ID: $PROMETHEUS_ID"
    echo "   • UID: $PROMETHEUS_UID"
else
    echo "❌ Prometheus data source not found. Creating one..."
    
    # Create prometheus data source
    CREATE_RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
        -d '{
            "name": "prometheus",
            "type": "prometheus", 
            "url": "http://localhost:9090",
            "access": "proxy",
            "isDefault": true,
            "basicAuth": false
        }' \
        "${GRAFANA_URL}/api/datasources")
    
    if echo "$CREATE_RESPONSE" | grep -q "Datasource added"; then
        PROMETHEUS_UID=$(echo "$CREATE_RESPONSE" | jq -r '.datasource.uid')
        PROMETHEUS_ID=$(echo "$CREATE_RESPONSE" | jq -r '.datasource.id')
        echo "✅ Created Prometheus data source with UID: $PROMETHEUS_UID"
    else
        echo "❌ Failed to create data source: $CREATE_RESPONSE"
        exit 1
    fi
fi

# Step 2: Create a simple working dashboard
echo ""
echo "2️⃣ Creating a working test dashboard..."

# Create a simple dashboard with proper data source reference
cat > working-dashboard.json << EOF
{
  "dashboard": {
    "id": null,
    "title": "Working Dashboard Test",
    "tags": ["test", "working"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Node Status (UP)",
        "type": "stat", 
        "targets": [
          {
            "expr": "up",
            "datasource": {
              "type": "prometheus",
              "uid": "${PROMETHEUS_UID}"
            }
          }
        ],
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Kubernetes Nodes",
        "type": "stat",
        "targets": [
          {
            "expr": "kube_node_info",
            "datasource": {
              "type": "prometheus",
              "uid": "${PROMETHEUS_UID}"
            }
          }
        ],
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "CPU Usage %",
        "type": "timeseries",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "datasource": {
              "type": "prometheus", 
              "uid": "${PROMETHEUS_UID}"
            }
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Memory Usage",
        "type": "timeseries",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "datasource": {
              "type": "prometheus",
              "uid": "${PROMETHEUS_UID}"
            }
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
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

# Upload the working dashboard
echo "📤 Uploading working dashboard..."
UPLOAD_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    -d @working-dashboard.json \
    "${GRAFANA_URL}/api/dashboards/db")

if echo "$UPLOAD_RESPONSE" | grep -q '"status":"success"'; then
    DASHBOARD_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.url')
    echo "✅ Working dashboard uploaded successfully!"
    echo ""
    echo "🔗 Test this dashboard first:"
    echo "   ${GRAFANA_URL}${DASHBOARD_URL}"
    echo ""
    echo "This should show live data. If it works, the issue was data source configuration."
else
    echo "❌ Upload failed: $UPLOAD_RESPONSE"
fi

echo ""
echo "3️⃣ Next steps:"
echo ""
echo "A) Test the working dashboard first"
echo "B) If it shows data, we need to fix the main dashboard"
echo "C) The issue is likely that the main dashboard uses wrong data source UID"
echo ""
echo "🎯 To fix your main dashboard:"
echo "1. Edit grafana-detailed-dashboard.json" 
echo "2. Replace all data source references with:"
echo "   \"datasource\": {\"type\": \"prometheus\", \"uid\": \"${PROMETHEUS_UID}\"}"
echo "3. Re-upload the dashboard"

# Offer to fix the main dashboard
echo ""
read -p "🔧 Would you like me to fix and re-upload your main dashboard now? (y/n): " FIX_MAIN

if [[ "$FIX_MAIN" =~ ^[Yy]$ ]]; then
    echo ""
    echo "4️⃣ Fixing main dashboard data source references..."
    
    # Create backup
    cp grafana-detailed-dashboard.json grafana-detailed-dashboard.backup.json
    
    # Fix data source references
    sed -i '' 's/"datasource": "prometheus"/"datasource": {"type": "prometheus", "uid": "'${PROMETHEUS_UID}'"}/g' grafana-detailed-dashboard.json
    
    # Re-upload main dashboard  
    echo "📤 Re-uploading fixed main dashboard..."
    MAIN_UPLOAD=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
        -d @grafana-detailed-dashboard.json \
        "${GRAFANA_URL}/api/dashboards/db")
    
    if echo "$MAIN_UPLOAD" | grep -q '"status":"success"'; then
        MAIN_URL=$(echo "$MAIN_UPLOAD" | jq -r '.url')
        echo "✅ Main dashboard fixed and re-uploaded!"
        echo ""
        echo "🎉 Your fixed dashboard:"
        echo "   ${GRAFANA_URL}${MAIN_URL}"
        echo ""
        echo "✅ All 24 panels should now show live data!"
    else
        echo "❌ Main dashboard upload failed: $MAIN_UPLOAD"
    fi
fi

echo ""
echo "🎊 Dashboard troubleshooting complete!"