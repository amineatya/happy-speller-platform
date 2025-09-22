# Jenkins Kubernetes Plugin Setup

## Install the Plugin

1. Go to Jenkins → Manage Jenkins → Manage Plugins
2. Go to the "Available" tab
3. Search for "Kubernetes"
4. Check the "Kubernetes" plugin (by CloudBees)
5. Click "Install without restart" or "Download now and install after restart"

## Configure the Plugin

After installation:

1. Go to Jenkins → Manage Jenkins → Configure System
2. Scroll down to "Cloud" section
3. Click "Add a new cloud" → "Kubernetes"
4. Configure:
   - **Name**: kubernetes
   - **Kubernetes URL**: Your Kubernetes API server URL (e.g., https://your-k8s-api:6443)
   - **Kubernetes Namespace**: jenkins (or your preferred namespace)
   - **Credentials**: Add your kubeconfig as a secret file credential
   - **Jenkins URL**: http://jenkins-service:8080 (internal cluster URL)

## Required Plugins

Make sure these plugins are also installed:
- Kubernetes Plugin
- Kubernetes CLI Plugin
- Pipeline Stage View Plugin
- Blue Ocean Plugin (optional but recommended)

## Test Configuration

After setup, your Jenkinsfile should work with the kubernetes agent block.