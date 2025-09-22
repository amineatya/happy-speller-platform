# 📊 Happy Speller Platform - Grafana Dashboard Setup

## 🎯 Dashboard Overview

This dashboard provides comprehensive monitoring for your Happy Speller Platform including:

- **Infrastructure Status** (Talos Kubernetes nodes)
- **Jenkins Build Status** (CI/CD pipeline health)
- **Kubernetes Cluster Overview** (pods, deployments)
- **System Metrics** (CPU, Memory, Network)
- **Application Metrics** (HTTP requests, response times)
- **Service Health Checks** (all endpoints)

## 🔧 Installation Methods

### Method 1: Manual Upload (Recommended)

1. **Open Grafana**: `http://192.168.50.97:3000`
2. **Login** with your Grafana credentials
3. **Navigate to**: Dashboard → Import (or go to `/dashboard/import`)
4. **Upload file**: Select `grafana-dashboard.json`
5. **Click**: "Load" → "Import"

### Method 2: API Upload (Advanced)

If you know your Grafana credentials, update the script:

```bash
# Edit upload-grafana-dashboard.sh
GRAFANA_USER="your_username"
GRAFANA_PASS="your_password"

# Run the script
./upload-grafana-dashboard.sh
```

## 📋 Dashboard Panels

### 🏗️ Infrastructure Monitoring
- **Infrastructure Status**: Shows UP/DOWN status of all nodes
- **Kubernetes Cluster Overview**: Node information and versions
- **Application Pods Status**: Running/Failed pods in demo namespace

### 🔧 CI/CD Monitoring  
- **Jenkins Build Status**: Latest build results (SUCCESS/FAILURE/UNSTABLE)
- Links to Jenkins, Gitea, and MinIO

### 📈 System Metrics
- **CPU Usage**: Real-time CPU utilization per node
- **Memory Usage**: Memory consumption percentage
- **Network I/O**: Network traffic in/out

### 🌐 Application Monitoring
- **Happy Speller App Metrics**: HTTP request rates
- **Response Time**: 95th and 50th percentile response times
- **Service Endpoints Health**: Uptime monitoring for all services

## 🔗 Quick Links

The dashboard includes direct links to:
- **Jenkins**: `http://192.168.50.247:8080`
- **Gitea**: `http://192.168.50.130:3000`  
- **MinIO**: `http://192.168.50.177:9001`

## ⚡ Data Sources Required

For full functionality, ensure these data sources are configured in Grafana:

### 1. Prometheus (Primary)
- **URL**: `http://prometheus-server:9090` (or your Prometheus endpoint)
- **Access**: Server (default)

### 2. Node Exporter Metrics
Required metrics:
```
- up{job="node-exporter"}
- node_memory_MemAvailable_bytes
- node_memory_MemTotal_bytes
- node_cpu_seconds_total
- node_network_receive_bytes_total
- node_network_transmit_bytes_total
```

### 3. Kubernetes Metrics (kube-state-metrics)
Required metrics:
```
- kube_node_info
- kube_pod_status_phase
```

### 4. Jenkins Metrics (if Jenkins Prometheus plugin installed)
Required metrics:
```
- jenkins_builds_last_build_result_ordinal
```

### 5. Application Metrics (if app has Prometheus metrics)
Required metrics:
```
- http_requests_total{service="happy-speller"}
- http_request_duration_seconds_bucket{service="happy-speller"}
```

## 🚀 Setup Data Sources

### Install Missing Exporters

1. **Node Exporter** (on each Talos node):
```bash
# Talos already includes node_exporter typically
# Check with: kubectl get pods -A | grep node-exporter
```

2. **kube-state-metrics**:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard/service.yaml
```

3. **Prometheus** (if not installed):
```bash
# Using Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

## 🎨 Dashboard Features

- **Auto-refresh**: 30 seconds
- **Time Range**: Last 1 hour (adjustable)
- **Responsive**: Works on desktop and mobile
- **Color-coded**: Green=Good, Yellow=Warning, Red=Critical
- **Interactive**: Click panels to drill down

## 🔧 Customization

Edit `grafana-dashboard.json` to:
- Change refresh intervals
- Modify alert thresholds
- Add custom panels
- Update service endpoints
- Change color schemes

## 📊 Expected Metrics

Once data sources are configured, you should see:

✅ **Green Status**: All services healthy
✅ **Build Success**: Recent Jenkins builds passing  
✅ **Pod Health**: All application pods running
✅ **Resource Usage**: CPU/Memory within normal ranges
✅ **Network**: Healthy traffic patterns

## 🆘 Troubleshooting

### No Data Showing?
1. Check Prometheus data source configuration
2. Verify metrics are being scraped: `http://prometheus:9090/targets`
3. Ensure correct job labels in queries

### Authentication Issues?
1. Reset Grafana admin password if needed
2. Check Grafana logs: `kubectl logs -n monitoring grafana-xxx`

### Dashboard Not Loading?
1. Try manual import via Grafana UI
2. Check JSON syntax in dashboard file
3. Verify Grafana version compatibility (12.x+)

---

## 🎉 Ready!

Your Happy Speller Platform dashboard is now ready to provide complete visibility into your infrastructure, CI/CD pipeline, and application health!

**Dashboard URL**: `http://192.168.50.97:3000/d/happy-speller-platform`