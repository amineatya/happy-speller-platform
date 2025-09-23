# Happy Speller Platform - Prometheus Monitoring Queries

Access Prometheus at: **http://192.168.50.183:30090**

## 🚀 Quick Start Queries

### **1. System Health Overview**
```promql
# All services status (1=up, 0=down)
up

# Count of healthy services
count(up == 1)

# Count of unhealthy services  
count(up == 0)
```

### **2. Happy Speller Application Monitoring**
```promql
# Happy Speller pods status
kube_pod_status_ready{namespace=~"demo|happy-speller-.*"}

# Happy Speller pod restarts (high restarts indicate problems)
increase(kube_pod_container_status_restarts_total{namespace=~"demo|happy-speller-.*"}[5m])

# Happy Speller pod CPU usage
rate(container_cpu_usage_seconds_total{namespace=~"demo|happy-speller-.*"}[5m]) * 100

# Happy Speller pod memory usage (MB)
container_memory_usage_bytes{namespace=~"demo|happy-speller-.*"} / 1024 / 1024
```

## 📊 Infrastructure Monitoring

### **3. Node Health & Resources**
```promql
# CPU usage per node (percentage)
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage per node (percentage) 
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage per node (percentage)
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)

# Load average (1 minute)
node_load1

# Network traffic (bytes per second)
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])
```

### **4. Kubernetes Cluster Health**
```promql
# Total pods in cluster
count(kube_pod_info)

# Running pods
count(kube_pod_status_phase{phase="Running"})

# Failed pods
count(kube_pod_status_phase{phase="Failed"}) 

# Pending pods
count(kube_pod_status_phase{phase="Pending"})

# Node readiness
kube_node_status_condition{condition="Ready",status="true"}
```

## 🔧 ArgoCD & GitOps Monitoring

### **5. ArgoCD Application Health**
```promql
# ArgoCD pods status
kube_pod_status_ready{namespace="argocd"}

# Count of ArgoCD apps by sync status
count by(sync_status) (argocd_app_info)

# Count of ArgoCD apps by health status  
count by(health_status) (argocd_app_info)

# ArgoCD sync failures (if metric available)
increase(argocd_app_sync_total{phase="Failed"}[5m])
```

### **6. Application Deployment Tracking**
```promql
# Deployments by namespace
count by(namespace) (kube_deployment_status_replicas_available)

# Deployment replica status
kube_deployment_status_replicas_available / kube_deployment_spec_replicas

# Services by namespace
count by(namespace) (kube_service_info)
```

## 📈 Performance & Alerting Queries

### **7. Resource Usage Alerts**
```promql
# High CPU usage (>80%)
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80

# High memory usage (>85%)
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85

# High disk usage (>90%)
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100) > 90

# Pods with high restart count (>5 in last hour)
increase(kube_pod_container_status_restarts_total[1h]) > 5
```

### **8. Application Performance**
```promql
# Container CPU throttling
rate(container_cpu_cfs_throttled_seconds_total[5m])

# Container memory pressure  
container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.8

# Pod scheduling issues (pending too long)
kube_pod_status_phase{phase="Pending"} and on(pod) kube_pod_created < time() - 300
```

## 🎯 Business/Application Specific

### **9. Happy Speller Specific Metrics**
```promql
# Happy Speller service availability
up{job=~".*happy-speller.*"}

# Demo namespace health (your main app)
avg(kube_pod_status_ready{namespace="demo"})

# GitOps environments health
avg by(namespace) (kube_pod_status_ready{namespace=~"happy-speller-.*"})

# Application uptime
(time() - kube_pod_created{namespace=~"demo|happy-speller-.*"}) / 3600
```

### **10. Network & Connectivity**
```promql
# Service endpoints availability
kube_endpoint_ready{namespace=~"demo|happy-speller-.*|argocd"}

# DNS resolution performance (if available)
probe_dns_lookup_time_seconds

# Service discovery health
count by(namespace) (kube_service_info{namespace=~"demo|happy-speller-.*|argocd"})
```

## 📋 How to Use These Queries

### **In Prometheus Web UI:**
1. Go to **http://192.168.50.183:30090**
2. Click **"Graph"** tab
3. Enter any query from above
4. Click **"Execute"**
5. View results in **Table** or **Graph** format

### **Useful Tips:**
- **`[5m]`** = 5-minute time range
- **`rate()`** = per-second rate over time range  
- **`increase()`** = total increase over time range
- **`avg by(label)`** = average grouped by label
- **`count()`** = count number of results

### **Time Ranges:**
- **`[1m]`** - 1 minute
- **`[5m]`** - 5 minutes  
- **`[1h]`** - 1 hour
- **`[1d]`** - 1 day

### **Math Operations:**
- **`* 100`** = convert to percentage
- **`/ 1024 / 1024`** = convert bytes to MB
- **`> 80`** = filter results greater than 80

## 🔥 Quick Monitoring Dashboard Queries

**Copy these into Prometheus for instant insights:**

```promql
# System Overview (paste each in separate graph)
count(up == 1)                                    # Services Up
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)  # CPU %
(1 - (avg(node_memory_MemAvailable_bytes) / avg(node_memory_MemTotal_bytes))) * 100  # Memory %
count(kube_pod_status_phase{phase="Running"})     # Running Pods
avg(kube_pod_status_ready{namespace="demo"})      # Happy Speller Health
```

## 🚨 Alerting Queries

**These queries can be used for alerting (when they return results, there's an issue):**

```promql
up == 0                                           # Service Down
increase(kube_pod_container_status_restarts_total[5m]) > 0  # Pod Restart
kube_pod_status_phase{phase="Failed"}            # Failed Pods  
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85  # High Memory
```

Happy monitoring! 📊 🚀