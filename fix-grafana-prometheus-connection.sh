#!/bin/bash

echo "🔧 Fixing Grafana → Prometheus Connection"
echo "========================================="
echo ""

# The Problem: Grafana (on 192.168.50.97) cannot reach localhost:9090
# Solution: Use the Kubernetes service directly or expose via NodePort

echo "🔍 Problem Diagnosis:"
echo "   • Grafana is running on 192.168.50.97"
echo "   • Prometheus port-forward is on YOUR localhost:9090"
echo "   • Grafana cannot reach 'localhost:9090' from a different machine"
echo ""

# Get user machine IP for alternative solution
USER_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -n1 | awk '{print $2}')
echo "🖥️  Your machine IP: $USER_IP"
echo ""

echo "🎯 Solutions available:"
echo ""
echo "Option 1: Use your machine IP (Quick Fix)"
echo "   • Update Grafana data source URL to: http://$USER_IP:9090"
echo "   • Keep port-forward running on your machine"
echo ""
echo "Option 2: Use Kubernetes NodePort (Permanent)"
echo "   • Expose Prometheus via NodePort on Kubernetes"
echo "   • Update Grafana to use NodePort URL"
echo ""

read -p "Choose solution (1 for Machine IP, 2 for NodePort): " SOLUTION

if [[ "$SOLUTION" == "1" ]]; then
    echo ""
    echo "🔧 Option 1: Using your machine IP"
    echo "================================"
    
    # Get Grafana credentials
    echo "🔐 Enter Grafana credentials:"
    read -p "Username: " GRAFANA_USER
    read -s -p "Password: " GRAFANA_PASS
    echo ""
    
    GRAFANA_URL="http://192.168.50.97:3000"
    NEW_PROMETHEUS_URL="http://$USER_IP:9090"
    
    echo "🔄 Updating Prometheus data source URL..."
    echo "   From: http://localhost:9090"
    echo "   To: $NEW_PROMETHEUS_URL"
    
    # Update the data source
    UPDATE_RESPONSE=$(curl -s -X PUT \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
        -d "{
            \"id\": 1,
            \"name\": \"prometheus\",
            \"type\": \"prometheus\",
            \"url\": \"$NEW_PROMETHEUS_URL\",
            \"access\": \"proxy\",
            \"isDefault\": true,
            \"basicAuth\": false
        }" \
        "$GRAFANA_URL/api/datasources/1")
    
    if echo "$UPDATE_RESPONSE" | grep -q "Datasource updated"; then
        echo "✅ Data source updated successfully!"
        
        # Test the connection
        echo "🧪 Testing connection..."
        sleep 2
        TEST_RESPONSE=$(curl -s -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
            "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=up")
        
        if echo "$TEST_RESPONSE" | grep -q "success"; then
            echo "✅ Connection test successful!"
            echo ""
            echo "🎉 Your dashboard should now show data!"
            echo "📊 Refresh your dashboard: http://192.168.50.97:3000/d/da2f2f11-9a5c-4e88-9d93-21420c75318d/"
        else
            echo "⚠️  Connection test response: $TEST_RESPONSE"
            echo ""
            echo "🛠️  Troubleshooting steps:"
            echo "1. Make sure port forwarding is running:"
            echo "   kubectl --kubeconfig ./kubeconfig-talos port-forward -n monitoring service/prometheus 9090:9090"
            echo "2. Make sure your firewall allows connections from $GRAFANA_IP"
            echo "3. Test manually: curl http://$NEW_PROMETHEUS_URL/api/v1/query?query=up"
        fi
    else
        echo "❌ Failed to update data source: $UPDATE_RESPONSE"
    fi
    
elif [[ "$SOLUTION" == "2" ]]; then
    echo ""
    echo "🔧 Option 2: NodePort Service (Permanent Solution)"
    echo "=============================================="
    
    echo "📦 Creating NodePort service for Prometheus..."
    
    # Create NodePort service
    cat > prometheus-nodeport.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: prometheus-nodeport
  namespace: monitoring
spec:
  type: NodePort
  ports:
    - port: 9090
      targetPort: 9090
      nodePort: 30090
  selector:
    app.kubernetes.io/name: prometheus
EOF
    
    # Apply the service
    kubectl --kubeconfig ./kubeconfig-talos apply -f prometheus-nodeport.yaml
    
    if [[ $? -eq 0 ]]; then
        echo "✅ NodePort service created successfully!"
        
        # Get node IP
        NODE_IP=$(kubectl --kubeconfig ./kubeconfig-talos get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        PROMETHEUS_NODEPORT_URL="http://$NODE_IP:30090"
        
        echo "🌐 Prometheus is now accessible at: $PROMETHEUS_NODEPORT_URL"
        
        # Test NodePort access
        echo "🧪 Testing NodePort access..."
        sleep 5
        if curl -s --connect-timeout 10 "$PROMETHEUS_NODEPORT_URL/api/v1/query?query=up" >/dev/null; then
            echo "✅ NodePort is accessible!"
            
            # Get Grafana credentials
            echo ""
            echo "🔐 Enter Grafana credentials to update data source:"
            read -p "Username: " GRAFANA_USER
            read -s -p "Password: " GRAFANA_PASS
            echo ""
            
            # Update Grafana data source
            echo "🔄 Updating Grafana data source to use NodePort..."
            UPDATE_RESPONSE=$(curl -s -X PUT \
                -H "Content-Type: application/json" \
                -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
                -d "{
                    \"id\": 1,
                    \"name\": \"prometheus\",
                    \"type\": \"prometheus\",
                    \"url\": \"$PROMETHEUS_NODEPORT_URL\",
                    \"access\": \"proxy\",
                    \"isDefault\": true,
                    \"basicAuth\": false
                }" \
                "http://192.168.50.97:3000/api/datasources/1")
            
            if echo "$UPDATE_RESPONSE" | grep -q "Datasource updated"; then
                echo "✅ Grafana data source updated to NodePort!"
                echo ""
                echo "🎉 Your dashboard should now show data permanently!"
                echo "📊 No more port-forwarding needed!"
                echo "🔗 Dashboard: http://192.168.50.97:3000/d/da2f2f11-9a5c-4e88-9d93-21420c75318d/"
            else
                echo "❌ Failed to update Grafana: $UPDATE_RESPONSE"
            fi
        else
            echo "❌ NodePort is not accessible. Check your cluster network."
        fi
    else
        echo "❌ Failed to create NodePort service"
    fi
    
else
    echo "❌ Invalid option selected"
    exit 1
fi

echo ""
echo "🎯 Summary:"
echo "   • The issue was that Grafana couldn't reach localhost:9090 from a different machine"
echo "   • Solution chosen: Option $SOLUTION"
echo "   • Your dashboard should now display live metrics!"
echo ""
echo "💡 If you still see 'No data', wait 15-30 seconds for refresh or:"
echo "   • Click the refresh button in Grafana"
echo "   • Check the time range (top right) - set to 'Last 5 minutes'"