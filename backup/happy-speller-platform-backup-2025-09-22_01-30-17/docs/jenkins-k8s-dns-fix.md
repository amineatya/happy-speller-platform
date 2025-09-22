# Jenkins Kubernetes DNS Resolution Fix

## 🔍 Problem
Jenkins is trying to resolve `kubernetes.default.svc` instead of using the external API endpoint from your kubeconfig.

## ✅ Your Setup Status
- **Kubeconfig**: ✅ Correctly configured with external endpoint `https://192.168.50.226:6443`
- **Cluster connectivity**: ✅ Working (tested successfully)
- **Issue**: Jenkins configuration or plugins trying to use internal cluster DNS

## 🛠️ Solutions (Try in Order)

### Solution 1: Check Jenkins Kubernetes Plugin Configuration

1. Go to Jenkins: `http://192.168.50.247:8080/manage/configureClouds/`
2. Look for any **Kubernetes Cloud** configurations
3. If found, either:
   - **Delete** the cloud configuration (if not needed)
   - **Update** the "Kubernetes URL" to: `https://192.168.50.226:6443`

### Solution 2: Disable Kubernetes Credentials Provider (If Not Needed)

1. Go to: `http://192.168.50.247:8080/manage/pluginManager/installed`
2. Search for "Kubernetes Credentials Provider"
3. If found and not needed, **disable** it
4. Restart Jenkins

### Solution 3: Check Jenkins System Configuration

1. Go to: `http://192.168.50.247:8080/manage/configure`
2. Look for any Kubernetes-related configurations
3. Ensure no plugins are trying to auto-discover Kubernetes

### Solution 4: Update Your Pipeline (Recommended)

Since your pipeline uses `withCredentials([file(credentialsId: 'kubeconfig'...)])`, make sure the KUBECONFIG environment variable is properly set in the pipeline context.

Update your Jenkinsfile stages that use kubectl/helm:

```groovy
withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG_FILE')]) {
    sh """
        export KUBECONFIG=\${KUBECONFIG_FILE}
        kubectl get nodes
        # ... rest of your commands
    """
}
```

### Solution 5: Add Host Resolution (If Needed)

If Jenkins is running on a Linux system and you need to resolve `kubernetes.default.svc`:

```bash
# On the Jenkins server
echo "192.168.50.226 kubernetes.default.svc" | sudo tee -a /etc/hosts
```

## 🧪 Test Commands

Test these on your Jenkins server to verify connectivity:

```bash
# Test API connectivity
curl -k https://192.168.50.226:6443/version

# Test with your kubeconfig
kubectl --kubeconfig /path/to/kubeconfig-talos get nodes

# Test DNS resolution (should fail, that's OK)
nslookup kubernetes.default.svc
```

## 🔧 Quick Fix for Pipeline

Add this to the beginning of your Kubernetes stages in Jenkinsfile:

```groovy
withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG_FILE')]) {
    sh '''
        export KUBECONFIG=${KUBECONFIG_FILE}
        # Verify connection works
        kubectl get nodes
        # Your actual commands here...
    '''
}
```

## 📝 Next Steps

1. **Upload your kubeconfig** to Jenkins (as planned)
2. **Check Jenkins cloud configuration** (Solution 1)
3. **Test your pipeline** 
4. If still failing, **disable Kubernetes auto-discovery plugins** (Solution 2)

Your kubeconfig is perfect - the issue is just Jenkins configuration! 🎯