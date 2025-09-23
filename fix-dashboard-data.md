# 🔧 Fix Your Grafana Dashboard - Data Source Setup

## ✅ **What We've Done**

Your monitoring stack is now running in Kubernetes:
- ✅ **Prometheus** - Collecting metrics from your cluster
- ✅ **Node Exporter** - System metrics (CPU, memory, disk, network)
- ✅ **Kube State Metrics** - Kubernetes cluster metrics
- ✅ **Port Forward** - Prometheus accessible at localhost:9090

## 🎯 **Update Dashboard Data Source**

Your dashboard shows "No data" because it needs to be configured to use the Prometheus data source.

### **Method 1: Via Grafana UI (Recommended)**

1. **Open your dashboard**: `http://192.168.50.97:3000/d/08d0e518-75e6-4111-a0f1-048a039bb43a`
2. **Click the gear icon** (⚙️) at the top right → "Dashboard settings"
3. **Go to "Variables"** tab
4. **Edit each variable** and set the data source to "prometheus"
5. **Save** the dashboard

### **Method 2: Quick Fix - Set Default Data Source**

The Prometheus data source should already be configured. Let me verify it's the default:

1. Go to **Configuration** → **Data Sources** in Grafana
2. Make sure **"prometheus"** is listed and set as default
3. The URL should be: `http://localhost:9090`

## 🚀 **Start Port Forward (Keep This Running)**

For the dashboard to work, keep this command running in a terminal:

```bash
kubectl --kubeconfig ./kubeconfig-talos port-forward -n monitoring service/prometheus 9090:9090
```

**Or run our automated script:**
```bash
./start-monitoring.sh
```

## 📊 **What Metrics You'll See**

Once configured, your dashboard will show:

### **✅ Working Panels:**
- 🏗️ **Infrastructure Status** - Node UP/DOWN status
- ☸️ **Kubernetes Pods Health** - Running/Failed/Pending pods  
- 💻 **CPU Usage** - Real-time CPU utilization per node
- 🧠 **Memory Usage** - Memory consumption by node
- 🌐 **Network I/O** - Network traffic rates
- 📊 **Kubernetes Cluster Overview** - Node details and versions

### **⚠️ Panels That May Show "No Data" Initially:**
- 🚀 **Jenkins metrics** - Requires Jenkins Prometheus plugin
- 🌐 **Application metrics** - Requires your app to expose Prometheus metrics
- 🗃️ **Database metrics** - Requires database exporters
- 🌡️ **Temperature/Power** - May not be available on all systems

## 🎉 **Expected Result**

After fixing the data source, you should see:
- **Green UP status** for your Talos nodes
- **CPU and Memory graphs** with real data
- **Pod counts** showing running pods
- **Network traffic** visualization
- **Kubernetes cluster information**

## 🆘 **Troubleshooting**

### **If Dashboard Still Shows "No Data":**

1. **Check Prometheus is accessible:**
   ```bash
   curl http://localhost:9090/api/v1/targets
   ```

2. **Verify port-forward is running:**
   ```bash
   lsof -i :9090
   ```

3. **Test a simple query:**
   - Open Grafana → Explore
   - Select "prometheus" data source
   - Query: `up`
   - Should show your nodes as UP

4. **Check monitoring pods:**
   ```bash
   kubectl --kubeconfig ./kubeconfig-talos get pods -n monitoring
   ```

## 🎯 **Next Steps**

1. **Keep port-forward running** (essential for data)
2. **Refresh your dashboard** - data should appear within 15 seconds
3. **Explore the metrics** - 24 panels of comprehensive monitoring!
4. **Optional**: Set up permanent access using NodePort or Ingress

Your monitoring infrastructure is ready - just need to connect the data source! 🚀📊