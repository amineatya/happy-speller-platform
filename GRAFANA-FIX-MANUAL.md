# 🔧 **URGENT FIX: Grafana Dashboard "No Data" Issue**

## 🎯 **Root Cause Identified**
Your Grafana (on `192.168.50.97`) cannot reach `localhost:9090` because that's localhost on **your machine**, not on the Grafana server.

## ✅ **Quick Fix (2 minutes)**

### **Step 1: Open Grafana Data Source Settings**
1. Go to: **http://192.168.50.97:3000**
2. Login with your credentials 
3. Click **⚙️ Configuration** → **Data Sources** (gear icon in sidebar)
4. Click on **"prometheus"** data source

### **Step 2: Update the URL**
**Current URL:** `http://localhost:9090`
**Change to:** `http://192.168.1.34:9090` 

*(This is your Mac's IP address - Grafana can reach it)*

### **Step 3: Test & Save**
1. Click **"Save & Test"** button at bottom
2. Should show **green ✅ "Data source is working"**
3. If red ❌, check that port forwarding is running (see below)

## 🚀 **Keep Port Forward Running**
```bash
kubectl --kubeconfig ./kubeconfig-talos port-forward -n monitoring service/prometheus 9090:9090
```

## 📊 **Result**
Your dashboard should immediately show live data:
- **Node Status**: 2 nodes UP
- **CPU/Memory**: Real-time graphs  
- **Kubernetes Metrics**: Pod counts, etc.

---

## 🔄 **Alternative: Permanent NodePort Solution**

If the above doesn't work, create permanent access:

### **Step 1: Create NodePort Service**
```bash
kubectl --kubeconfig ./kubeconfig-talos apply -f - << 'EOF'
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
```

### **Step 2: Update Grafana Data Source URL**
**Use:** `http://192.168.50.183:30090`
*(No more port-forwarding needed!)*

---

## 🧪 **Test Your Fix**

Run this to verify Prometheus is accessible:
```bash
# Test current port-forward
curl http://192.168.1.34:9090/api/v1/query?query=up

# Test NodePort (if you created it)  
curl http://192.168.50.183:30090/api/v1/query?query=up
```

Both should return JSON with `"status":"success"`

---

## 🎉 **Expected Result**

After fixing the URL, your dashboard will show:
- ✅ **Infrastructure Status**: Nodes UP
- ✅ **CPU Usage**: Real-time per node
- ✅ **Memory Usage**: Memory consumption 
- ✅ **Kubernetes Pods**: Running/Failed counts
- ✅ **Network I/O**: Traffic rates
- ✅ **All 24 panels**: Live metrics!

**Dashboard URL:** http://192.168.50.97:3000/d/da2f2f11-9a5c-4e88-9d93-21420c75318d/

The fix is simple - just change the data source URL in Grafana UI! 🚀